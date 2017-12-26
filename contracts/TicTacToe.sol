pragma solidity ^0.4.18;

contract TicTacToe {
    event GameCreation(uint gameIndex);

    uint8 private constant STATE_SHIFT = 0;
    uint8 private constant CURRENT_PLAYER_SHIFT = 2;
    uint8 private constant MOVES_SHIFT = 4;
    uint8 private constant BASE_FIELD_SHIFT = 8;
    uint8 private constant LAST_MOVE_SHIFT = 32;
    uint32 private constant LAST_MOVE_WIDTH = 4294967295;

    uint32 private constant MOVE_TIME_SECONDS = 20;

    uint8 public constant STATE_WAITING = 0;
    uint8 public constant STATE_PLAYING = 1;
    uint8 public constant STATE_FINISHED = 2;
    uint8 public constant STATE_CANCELED = 3;

    struct Game {
        // Packed game info
        uint64 info;
        // Address to player index mapping
        mapping(uint8 => address) players;
    }

    // We use a mapping with a counter as it is more gas efficient
    uint public gamesCounter = 0;
    mapping(uint => Game) private games;

    function getInfo(uint64 info, uint8 shift, uint32 width)
        private
        pure
        returns (uint32)
    {
        return uint32((info & (uint64(width) << shift)) >> shift);
    }

    function getInfo(uint64 info, uint8 shift)
        private
        pure
        returns (uint8)
    {
        return uint8(getInfo(info, shift, 3));
    }

    function setInfo(uint64 info, uint8 shift, uint32 value, uint32 width)
        private
        pure
        returns (uint64)
    {
        // TODO: Remove this require in prod to safe gas
        require(value <= width);
        info = info & ~(uint64(width) << shift);
        return info | (uint64(value) << shift);
    }

    function setInfo(uint64 info, uint8 shift, uint8 value)
        private
        pure
        returns (uint64)
    {
        return setInfo(info, shift, value, 3);
    }

    function create()
        payable
        public
    {
        require(msg.value == 1 ether);
        Game storage game = games[gamesCounter];
        game.players[1] = msg.sender;
        GameCreation(gamesCounter++);
    }

    function cancel(uint gameIndex)
        payable
        public
    {
        Game storage game = games[gameIndex];
        var _info = game.info;
        // Check no other player joined
        require(_info == 0);
        // Check if sender is player 1
        require(game.players[1] == msg.sender);
        // Finish game as Tie
        _info = setInfo(_info, CURRENT_PLAYER_SHIFT, 0);
        _info = setInfo(_info, STATE_SHIFT, STATE_CANCELED);
        game.info = _info;
        // Refund money
        msg.sender.transfer(1 ether);
    }

    function join(uint gameIndex)
        payable
        public
    {
        require(msg.value == 1 ether);
        require(gameIndex < gamesCounter);
        Game storage game = games[gameIndex];
        require(game.info == 0);
        require(game.players[1] != msg.sender);
        game.players[2] = msg.sender;
        var _info = setInfo(1, LAST_MOVE_SHIFT, uint32(now), LAST_MOVE_WIDTH);
        game.info = setInfo(_info, CURRENT_PLAYER_SHIFT, uint8(block.blockhash(block.number - 1) & 1) + 1);
    }

    function makeMove(uint gameIndex, uint8 field)
        payable
        public
    {
        require(field < 9);
        Game storage game = games[gameIndex];
        var _info = game.info;
        // Check that we are still playing
        require(getInfo(_info, STATE_SHIFT) == STATE_PLAYING);
        // Check that sender is current player
        var currentPlayer = getInfo(_info, CURRENT_PLAYER_SHIFT);
        require(game.players[currentPlayer] == msg.sender);
        // Check that field is still free
        var fieldShift = BASE_FIELD_SHIFT + 2 * field;
        require(getInfo(_info, fieldShift) == 0);
        _info = setInfo(_info, fieldShift, currentPlayer);
        _info = setInfo(_info, LAST_MOVE_SHIFT, uint32(now), LAST_MOVE_WIDTH);
        var moves = getInfo(_info, MOVES_SHIFT, 15) + 1;
        if (moves > 4 && checkState(_info, field, currentPlayer)) {
             _info = setInfo(_info, STATE_SHIFT, STATE_FINISHED);
             // Trasnfer funds to winner
             msg.sender.transfer(2 ether);
        } else if (moves >= 9) {
             _info = setInfo(_info, CURRENT_PLAYER_SHIFT, 0);
             _info = setInfo(_info, STATE_SHIFT, STATE_FINISHED);
             // Refund each player
             game.players[1].transfer(1 ether);
             game.players[2].transfer(1 ether);
        } else {
            // Game continues set next player
            _info = setInfo(_info, CURRENT_PLAYER_SHIFT, (currentPlayer % 2) + 1);
        }
        game.info = setInfo(_info, MOVES_SHIFT, moves, 15);
    }

    function checkState(uint64 info, uint8 field, uint8 currentPlayer)
        public
        pure
        returns (bool)
    {
        if (field == 0) return check0(info, currentPlayer);
        else if(field == 1) return check1(info, currentPlayer);
        else if(field == 2) return check2(info, currentPlayer);
        else if(field == 3) return check3(info, currentPlayer);
        else if(field == 4) return check4(info, currentPlayer);
        else if(field == 5) return check5(info, currentPlayer);
        else if(field == 6) return check6(info, currentPlayer);
        else if(field == 7) return check7(info, currentPlayer);
        else return check8(info, currentPlayer);
    }

    function check0(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 1) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 2) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 3) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 6) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 8) == currentPlayer);
    }

    function check1(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 0) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 2) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 7) == currentPlayer);
    }

    function check2(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 1) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 0) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 5) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 8) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 6) == currentPlayer);
    }

    function check3(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 0) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 6) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 5) == currentPlayer);
    }

    function check4(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 0) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 8) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 1) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 7) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 2) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 6) == currentPlayer);
    }

    function check5(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 2) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 8) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 3) == currentPlayer);
    }

    function check6(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 3) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 0) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 2) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 7) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 8) == currentPlayer);
    }

    function check7(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 6) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 8) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 1) == currentPlayer);
    }

    function check8(uint64 info, uint8 currentPlayer)
        private
        pure
        returns (bool)
    {
        return
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 5) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 2) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 4) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 0) == currentPlayer) ||
            (getInfo(info, BASE_FIELD_SHIFT + 2 * 7) == currentPlayer && getInfo(info, BASE_FIELD_SHIFT + 2 * 6) == currentPlayer);
    }

    function currentPlayerIndex(uint gameIndex)
        public
        view
        returns (uint8)
    {
        return uint8(getInfo(games[gameIndex].info, CURRENT_PLAYER_SHIFT));
    }

    function senderPlayerIndex(uint gameIndex)
        public
        view
        returns (uint8)
    {
        var players = games[gameIndex].players;
        if (players[1] == msg.sender) return 1;
        if (players[2] == msg.sender) return 2;
        return 0;
    }

    function currentGameState(uint gameIndex)
        public
        view
        returns (uint8)
    {
        return uint8(getInfo(games[gameIndex].info, STATE_SHIFT));
    }

    function currentMoves(uint gameIndex)
        public
        view
        returns (uint8)
    {
        return uint8(getInfo(games[gameIndex].info, MOVES_SHIFT));
    }

    function lastMove(uint gameIndex)
        public
        view
        returns (uint32)
    {
        return uint32(getInfo(games[gameIndex].info, LAST_MOVE_SHIFT, LAST_MOVE_WIDTH));
    }

    function currentPlayerCanBePunished(uint64 info)
        private
        view
        returns (bool)
    {
        var lastMoveTime = uint32(getInfo(info, LAST_MOVE_SHIFT, LAST_MOVE_WIDTH)) * 1 seconds;
        return getInfo(info, STATE_SHIFT) == STATE_PLAYING && (lastMoveTime + MOVE_TIME_SECONDS * 1 seconds) < now;
    }

    function canCurrentPlayerBePunished(uint gameIndex)
        public
        view
        returns (bool)
    {
        return currentPlayerCanBePunished(games[gameIndex].info);
    }

    function punishCurrentPlayer(uint gameIndex)
        public
    {
        Game storage game = games[gameIndex];
        var _info = game.info;
        var currentPlayer = getInfo(_info, CURRENT_PLAYER_SHIFT);
        var otherPlayer = (currentPlayer % 2) + 1;
        // Only other player should be able to punish
        require(game.players[otherPlayer] == msg.sender);
        require(currentPlayerCanBePunished(_info));
        // Set other player as current player and end the game
        // => therefore he is the winner and can redeem the winnings
        _info = setInfo(_info, CURRENT_PLAYER_SHIFT, otherPlayer);
        _info = setInfo(_info, STATE_SHIFT, STATE_FINISHED);
        game.info = _info;
    }

    function getGameInfo(uint gameIndex)
        public
        view
        returns (uint64)
    {
        require(gameIndex < gamesCounter);
        return games[gameIndex].info;
    }
}
