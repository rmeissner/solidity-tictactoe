pragma solidity ^0.4.19;

contract TicTacToe {
    uint8 private constant STATE_SHIFT = 0;
    uint8 private constant CURRENT_PLAYER_SHIFT = 2;
    uint8 private constant MOVES_SHIFT = 4;
    uint8 private constant BASE_FIELD_SHIFT = 8;
    uint8 private constant LAST_MOVE_SHIFT = 32;
    uint32 private constant LAST_MOVE_WIDTH = 4294967295;

    uint32 private constant MOVE_TIME_SECONDS = 20;

    struct Game {
        // Packed game info
        uint64 info;
        // Address to player index mapping
        mapping(address => uint8) players;
    }

    // We use a mapping with a counter as it is more gas efficient
    uint gamesCounter = 0;
    mapping(uint => Game) games;

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
        returns (uint)
    {
        require(msg.value == 1 ether);
        Game storage game = games[gamesCounter];
        game.players[msg.sender] = 1;
        return gamesCounter++;
    }

    function join(uint gameIndex)
        payable
        public
    {
        require(msg.value == 1 ether);
        require(gameIndex < gamesCounter);
        Game storage game = games[gameIndex];
        require(game.info == 0);
        require(game.players[msg.sender] == 0);
        game.players[msg.sender] = 2;
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
        require(getInfo(_info, STATE_SHIFT) == 1);
        // Check that sender is current player
        var currentPlayer = getInfo(_info, CURRENT_PLAYER_SHIFT);
        require(currentPlayer == game.players[msg.sender]);
        // Check that field is still free
        var fieldShift = BASE_FIELD_SHIFT + 2 * field;
        require(getInfo(_info, fieldShift) == 0);
        _info = setInfo(_info, fieldShift, currentPlayer);
        _info = setInfo(_info, LAST_MOVE_SHIFT, uint32(now), LAST_MOVE_WIDTH);
        var moves = getInfo(_info, MOVES_SHIFT, 15) + 1;
        if (moves > 4 && checkState(_info, field, currentPlayer)) {
             _info = setInfo(_info, STATE_SHIFT, 2);
        } else if (moves >= 9) {
             _info = setInfo(_info, CURRENT_PLAYER_SHIFT, 0);
             _info = setInfo(_info, STATE_SHIFT, 2);
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

    function currentGameSate(uint gameIndex)
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
        return getInfo(info, STATE_SHIFT) == 1 && (lastMoveTime + MOVE_TIME_SECONDS * 1 seconds) < now;
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
        // Only players should be able to punish
        require(game.players[msg.sender] != 0);
        var _info = game.info;
        require(currentPlayerCanBePunished(_info));
        // Set other player as current player and end the game
        // => therefore he is the winner and can redeem the winnings
        var currentPlayer = getInfo(_info, CURRENT_PLAYER_SHIFT);
        _info = setInfo(_info, CURRENT_PLAYER_SHIFT, (currentPlayer % 2) + 1);
        _info = setInfo(_info, STATE_SHIFT, 2);
        game.info = _info;
    }

    function getGameInfo(uint gameIndex)
        public
        view
        returns (uint64)
    {
        return games[gameIndex].info;
    }

    function redeem(uint gameIndex) 
        public
    {
        Game storage game = games[gameIndex];
        var _info = game.info;
        require(getInfo(_info, STATE_SHIFT) == 2);
        var playerIndex = game.players[msg.sender];
        require(playerIndex != 0);

        // Remove player from game
        game.players[msg.sender] = 0;
        var currentPlayer = getInfo(_info, CURRENT_PLAYER_SHIFT);
        // Check if Tie
        if (currentPlayer == 0) {
            // Refund bet
            msg.sender.transfer(1 ether);

        // Check if player is winner
        } else if (playerIndex == currentPlayer) {
            // Send winnings
            msg.sender.transfer(2 ether);
        }
    }
}
