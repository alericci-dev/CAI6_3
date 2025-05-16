// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VickreyAuction {
    address public owner;
    uint public startTime;
    uint public endTime;
    uint public maxPrice;
    uint public paymentAmount;
    address public winner;
    bool public auctionEnded;
    bool public deliveryConfirmed;
    bool public deliveryFailed;

    struct Bid {
        uint amount;
        uint deposit;
        uint timestamp;
    }

    mapping(address => Bid) public bids;
    address[] public participants;

    event AuctionFinalized(address winner, uint payment);
    event DeliveryConfirmed(address winner, uint payment, uint deposit);
    event DeliveryFailed(address winner, uint payment, uint deposit);
    event FundsWithdrawn(address owner, uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Subasta inactiva");
        require(!auctionEnded, "Subasta finalizada");
        _;
    }

    constructor(uint _startTime, uint _endTime, uint _maxPrice) payable {
        require(_startTime < _endTime, "Fechas invalidas");
        require(msg.value == _maxPrice, "Deposito maximo requerido");
        owner = msg.sender;
        startTime = _startTime;
        endTime = _endTime;
        maxPrice = _maxPrice;
    }

    function bid(uint _amount) external payable auctionActive {
        require(_amount > 0 && _amount <= maxPrice, "Monto invalido");
        require(bids[msg.sender].amount == 0, "Ya participaste");
        require(participants.length < 30, "Maximo de pujas");
        require(msg.value >= (_amount * 10) / 100, "Deposito insuficiente");

        bids[msg.sender] = Bid(_amount, msg.value, block.timestamp);
        participants.push(msg.sender);
    }

    function finalizeAuction() external {
        require(block.timestamp > endTime || participants.length >= 30, "Subasta activa");
        require(!auctionEnded, "Ya finalizada");

        auctionEnded = true;
        if (participants.length == 0) return;

        // Ordenar pujas
        address[] memory sorted = participants;
        for (uint i = 0; i < sorted.length - 1; i++) {
            for (uint j = i + 1; j < sorted.length; j++) {
                Bid memory a = bids[sorted[i]];
                Bid memory b = bids[sorted[j]];
                if (a.amount > b.amount || (a.amount == b.amount && a.timestamp > b.timestamp)) {
                    (sorted[i], sorted[j]) = (sorted[j], sorted[i]);
                }
            }
        }

        winner = sorted[0];
        paymentAmount = participants.length > 1 ? bids[sorted[1]].amount : bids[winner].amount;

        // Reembolsar perdedores
        for (uint i = 0; i < participants.length; i++) {
            address bidder = participants[i];
            if (bidder != winner) {
                payable(bidder).transfer(bids[bidder].deposit);
            }
        }

        emit AuctionFinalized(winner, paymentAmount);
    }
    function confirmDelivery() external onlyOwner {
        require(auctionEnded, "Subasta activa");
        uint deposit = bids[winner].deposit;
        payable(winner).transfer(paymentAmount + deposit);
        deliveryConfirmed = true;
        emit DeliveryConfirmed(winner, paymentAmount, deposit);
    }
    function markAsUndelivered() external onlyOwner {
        require(auctionEnded, "Subasta activa");
        uint deposit = bids[winner].deposit;
        payable(owner).transfer(paymentAmount + deposit);
        deliveryFailed = true;
        emit DeliveryFailed(winner, paymentAmount, deposit);
    }

    function getBids() external view returns (address[] memory, uint[] memory) {
        uint[] memory amounts = new uint[](participants.length);
        for (uint i = 0; i < participants.length; i++) {
            amounts[i] = bids[participants[i]].amount;
        }
        return (participants, amounts);
    }

    function withDrawRemaining() external onlyOwner {
        require(auctionEnded, "La subasta debe concluirse");
        require(address(this).balance > 0, "No hay fondos disponibles");
        require(winner == address(0) || deliveryConfirmed || deliveryFailed, "Espere confirmacion de entrega o penalizacion");

        uint amount = address(this).balance;
        payable(owner).transfer(amount);
        emit FundsWithdrawn(owner, amount);
    }
}