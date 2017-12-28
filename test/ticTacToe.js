const util = require('util');
const utils = require('./utils')
const { getParamFromTxEvent, assertRejects, logGasUsage } = utils

const TicTacToe = artifacts.require("./TicTacToe.sol")

async function setupGame(accounts, ticTacToe) {
  // Check initial state of contract
  assert.equal(await web3.eth.getBalance(ticTacToe.address), 0)
  assert.equal(await ticTacToe.gamesCounter(), 1)
  assertRejects(ticTacToe.getGameInfo(1), "Should not return game info for non-existing game")

  // Create game
  var tx = await ticTacToe.create({value: web3.toWei(1, 'ether')})
  logGasUsage("Created game", tx)
  var gameId = getParamFromTxEvent(tx, "gameIndex")
  assert.equal(gameId, 1)
  assert.equal(await ticTacToe.gamesCounter(), 2)
  assert.equal(await ticTacToe.getGameInfo(1), 0)
  assert.equal(await ticTacToe.senderPlayerIndex(1), 1)
  assert.equal(await web3.eth.getBalance(ticTacToe.address).toNumber(), web3.toWei(1, 'ether'))

  assertRejects(ticTacToe.join(1), "Should not be able to join own game")
  assertRejects(ticTacToe.join(1, {from: accounts[1]}), "Should only be able to join a game if exactly 1 ether is paid")
  assertRejects(ticTacToe.join(1, {from: accounts[1], value: web3.toWei(2, 'ether')}), "Should only create game if exactly 1 ether is paid")
  assertRejects(ticTacToe.join(2, {from: accounts[1], value: web3.toWei(1, 'ether')}), "Should not be able to join non-existing game")
  await ticTacToe.join(1, {from: accounts[1], value: web3.toWei(1, 'ether')})
  assert.equal(await web3.eth.getBalance(ticTacToe.address).toNumber(), web3.toWei(2, 'ether'))
  assert.notEqual(await ticTacToe.getGameInfo(1), 0)
  assert.equal(await ticTacToe.currentGameState(1), 1)
  assert.equal(await ticTacToe.senderPlayerIndex(1, {from: accounts[1]}), 2)
}

async function makeMove(accounts, ticTacToe, currentPlayer, previousMove, moves, game, field, expectedPlayerReset = false) {
  logGasUsage("Made move number " + (parseInt(moves) + 1), await ticTacToe.makeMove(game, field, {from: accounts[currentPlayer - 1]}))
  if (await ticTacToe.currentGameState(1) == 1) {
    // Player should only change if the game doesn't ends
    currentPlayer = (currentPlayer % 2) + 1
  } else if (expectedPlayerReset) {
    // In case of a tie the player should reset
    currentPlayer = 0
  }
  assert.equal(await ticTacToe.currentPlayerIndex(game), currentPlayer)

  var lastMove = await ticTacToe.lastMove(game)
  assert.ok("last move should be after previous move: " + lastMove + " vs " + previousMove, previousMove < lastMove)
  moves++
  assert.equal(moves, await ticTacToe.currentMoves(game))

  return [currentPlayer, lastMove, moves]
}

contract('TicTacToe', function(accounts) {

    let ticTacToe

    beforeEach(async function () {
        // Create TicTacToe
        ticTacToe = await TicTacToe.new()
    })

    it('Schould create a game and cancel',  async () => {
        // Check initial state of contract
        assert.equal(await web3.eth.getBalance(ticTacToe.address), 0)
        assert.equal(await ticTacToe.gamesCounter(), 1)
        assertRejects(ticTacToe.getGameInfo(1), "Should not return game info for non-existing game")

        // Create game
        assertRejects(ticTacToe.create(), "Should only create game if exactly 1 ether is paid")
        assertRejects(ticTacToe.create({value: web3.toWei(2, 'ether')}), "Should only create game if exactly 1 ether is paid")
        var tx = await ticTacToe.create({value: web3.toWei(1, 'ether')})
        var gameId = getParamFromTxEvent(tx, "gameIndex")
        assert.equal(gameId, 1)
        assert.equal(await ticTacToe.gamesCounter(), 2)
        assert.equal(await ticTacToe.getGameInfo(1), 0)
        assert.equal(await ticTacToe.senderPlayerIndex(1), 1)
        assert.equal(await web3.eth.getBalance(ticTacToe.address).toNumber(), web3.toWei(1, 'ether'))

        assertRejects(ticTacToe.join(1, web3.toWei(1, 'ether')), "Should not be able to join own game")
        assertRejects(ticTacToe.makeMove(1, 4), "Should not be able to make a move without a second player")
        assertRejects(ticTacToe.punishCurrentPlayer(1), "Should not be able to punish before game start")
        assertRejects(ticTacToe.cancel(1, {from: accounts[1]}), "Other users should not be able to cancel game")

        var accountBalance = await web3.eth.getBalance(accounts[0]).toNumber()
        await ticTacToe.cancel(1)
        assert.ok(accountBalance < web3.eth.getBalance(accounts[0]).toNumber(), "Stake should be refunded")
        assert.equal(await web3.eth.getBalance(ticTacToe.address).toNumber(), 0)
    })

    it('Schould create, join and end a game with a winner',  async () => {
        await setupGame(accounts, ticTacToe)
        var currentPlayer = await ticTacToe.currentPlayerIndex(1)
        var lastMove = await ticTacToe.lastMove(1)
        var moves = await ticTacToe.currentMoves(1)
        assert.notEqual(currentPlayer, 0)
        assert.notEqual(lastMove, 0)
        assert.equal(moves, 0)

        var account0Balance = await web3.eth.getBalance(accounts[0]).toNumber()
        var account1Balance = await web3.eth.getBalance(accounts[1]).toNumber()

        // Start playing
        assertRejects(ticTacToe.makeMove(1, 4, {from: accounts[(currentPlayer % 2)]}), "Should not be able to make a move if it is not my turn")
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 4)
        assertRejects(ticTacToe.makeMove(1, 4, {from: accounts[(currentPlayer % 2)]}), "Should not be able to make a move on a occupied field")
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 0)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 2)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 6)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 5)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 3)
        if (currentPlayer == 2) {
          assert.ok(account1Balance < web3.eth.getBalance(accounts[1]).toNumber(), "Winner should get all")
          assert.ok(account0Balance > web3.eth.getBalance(accounts[0]).toNumber(), "Looser should get nothing")
        } else {
          assert.ok(account0Balance < web3.eth.getBalance(accounts[0]).toNumber(), "Winner should get all")
          assert.ok(account1Balance > web3.eth.getBalance(accounts[1]).toNumber(), "Looser should get nothing")
        }
        assert.equal(await ticTacToe.currentGameState(1), 2)
        assert.equal(await web3.eth.getBalance(ticTacToe.address).toNumber(), 0)
    })

    it('Schould create, join and end a game in a tie',  async () => {
        await setupGame(accounts, ticTacToe)
        var currentPlayer = await ticTacToe.currentPlayerIndex(1)
        var lastMove = await ticTacToe.lastMove(1)
        var moves = await ticTacToe.currentMoves(1)
        assert.notEqual(currentPlayer, 0)
        assert.notEqual(lastMove, 0)
        assert.equal(moves, 0)

        var account0Balance = await web3.eth.getBalance(accounts[0]).toNumber()
        var account1Balance = await web3.eth.getBalance(accounts[1]).toNumber()
        // Start playing
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 2)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 4)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 6)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 3)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 5)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 8)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 0)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 1)
        var [currentPlayer, lastMove, moves] = await makeMove(accounts, ticTacToe, currentPlayer, lastMove, moves, 1, 7, true)
        assert.ok(account0Balance < web3.eth.getBalance(accounts[0]).toNumber(), "Stake should be refunded")
        assert.ok(account1Balance < web3.eth.getBalance(accounts[1]).toNumber(), "Stake should be refunded")
        assert.equal(await ticTacToe.currentGameState(1), 2)
        assert.equal(await web3.eth.getBalance(ticTacToe.address).toNumber(), 0)
    })
})
