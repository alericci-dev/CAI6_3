// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VickreyAuctionSimple {
    address payable public owner;
    uint256 public auctionStart;
    uint256 public auctionEnd;
    uint256 public deliveryDueDate;
    uint256 public maxBid;
    uint256 public numBidders;
    uint256 public constant MAX_BIDDERS = 3;
    uint256 public constant DEPOSIT_PERCENTAGE = 10;
    
    enum AuctionState { Open, Closed, Completed }
    AuctionState public state;

    struct Bid {
        address payable bidder;
        uint256 amount;
        uint256 deposit;
        uint256 timestamp;
        bool depositReturned;
    }
    
    Bid[] public bids;
    address[] public bidders;
    address payable public winner;
    uint256 public winningPrice;
    uint256 public winnerDeposit;
    
    event BidPlaced(address indexed bidder);
    event AuctionClosed(address indexed winner, uint256 winnerDeposit, uint256 winningPrice);
    event DepositReturned(address indexed bidder, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier auctionOpen() {
        require(state == AuctionState.Open, "Auction not active");
        require(block.timestamp >= auctionStart && block.timestamp <= auctionEnd, "Outside of the auction's time range");
        _;
    }

    constructor(
        uint256 _startDate,
        uint256 _endDate,
        uint256 _deliveryDueDate,
        uint256 _maxBid
    ) payable {
        require(msg.value >= _maxBid, "You have to deposit the amount of the maximum possible bid");
        require(_startDate < _endDate && _endDate < _deliveryDueDate, "Invalid auction dates");

        owner = payable(msg.sender);
        auctionStart = _startDate;
        auctionEnd = _endDate;
        deliveryDueDate = _deliveryDueDate;
        maxBid = _maxBid;
        state = AuctionState.Open;
    }


    function placeBid(uint256 _amount) external payable auctionOpen {
        require(_amount > 0, "The bid must be > 0");
        require(_amount <= maxBid, "The bid is higher than the maximum");
        require(!hasAlreadyBid(msg.sender), "You have already participated");
        require(numBidders < MAX_BIDDERS, "The auction has reached the maximum number of participants");
        require(msg.sender != owner, "You cannot place a bid on your own auction");
        require(msg.value == (_amount * DEPOSIT_PERCENTAGE) / 100, "The deposit must be at least 10% of the bid");

        numBidders += 1;

        bids.push(Bid(
            payable(msg.sender),
            _amount,
            block.timestamp,
            msg.value,
            false
        ));
        bidders.push(msg.sender);

        emit BidPlaced(msg.sender);
    }

    function finalizeAuction() external onlyOwner {
        require(state == AuctionState.Open, "Auction closed");
        require(block.timestamp >= auctionEnd || numBidders >= MAX_BIDDERS, "The auction cannot be closed earlier");
        _finalizeAuction();
    }

    function _finalizeAuction() private {
        state = AuctionState.Closed;
        (winner, winningPrice) = _determineWinner();
        emit AuctionClosed(winner, winnerDeposit, winningPrice);
    }


    function _determineWinner() private view returns (address payable, uint256) {
        require(bids.length > 0, "No offers");

        uint256 lowest = maxBid;
        uint256 secondLowest = maxBid;
        address payable winnerAddress;
        uint256 earliestTimestamp = type(uint256).max;

        for (uint256 i = 0; i < bids.length; i++) {
            uint256 amount = bids[i].amount;
            uint256 timestamp = bids[i].timestamp;

            if (amount < lowest) {
                secondLowest = lowest;
                lowest = amount;
                winnerAddress = bids[i].bidder;
                earliestTimestamp = timestamp;
            } else if (amount == lowest && timestamp < earliestTimestamp) {
                secondLowest = lowest;
                winnerAddress = bids[i].bidder;
                //_winnerDeposit = bids[i].deposit;
                earliestTimestamp = timestamp;
            } else if (amount < secondLowest && amount > lowest) {
                secondLowest = amount;
            }
        }

        return (winnerAddress, bids.length == 1 ? lowest : secondLowest);
    }


    function returnDeposits() external onlyOwner {
        require(state == AuctionState.Closed, "Auction still open");
        
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].bidder != winner && !bids[i].depositReturned) {
                bids[i].depositReturned = true;
                payable(bids[i].bidder).transfer(bids[i].deposit);
                emit DepositReturned(bids[i].bidder, bids[i].deposit);
            }
        }
        
        state = AuctionState.Completed;
    }


    function hasAlreadyBid(address bidder) public view returns (bool) {
        for (uint256 i = 0; i < bidders.length; i++) {
            if (bidders[i] == bidder) return true;
        }
        return false;
    }


    function getBidCount() public view returns (uint256) {
        return bids.length;
    }

    // Pay the winner
    function deliveryReceived() public onlyOwner {
        require(state == AuctionState.Completed, "Auction still open or didn't paid back the deposits yet");
        require(block.timestamp < deliveryDueDate, "The delivery is overdue");

        winner.transfer(winningPrice + winner.balance);
        owner.transfer(address(this).balance);
    }

    // Withdraw the money if the winner didn't deliver
    function notDelivered() public onlyOwner {
        require(state == AuctionState.Completed, "Auction still open or didn't paid back the deposits yet");
        require(block.timestamp > deliveryDueDate, "The delivery can still be made");

        owner.transfer(address(this).balance);
    }

}