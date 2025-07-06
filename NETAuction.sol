// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://cdn.jsdelivr.net/npm/@openzeppelin/contracts@4.9.3/token/ERC721/ERC721.sol";
import "https://cdn.jsdelivr.net/npm/@openzeppelin/contracts@4.9.3/access/Ownable.sol";

contract NFTAuction is ERC721, Ownable {
    struct Auction {
        uint tokenId;
        address seller;
        uint startPrice;
        uint highestBid;
        address highestBidder;
        uint endTime;
        bool ended;
        mapping(address => uint) bids;
    }

    uint public tokenCounter;
    uint public auctionCounter;
    mapping(uint => Auction) public auctions;

    event NFTMinted(uint tokenId, address owner);
    event AuctionCreated(uint tokenId, uint auctionId, uint endTime);
    event BidPlaced(uint auctionId, address bidder, uint amount);
    event AuctionEnded(uint auctionId, address winner, uint bid);

    constructor() ERC721("AuctionNFT", "ANFT") {}

    function mintNFT() external {
        tokenCounter++;
        _mint(msg.sender, tokenCounter);
        emit NFTMinted(tokenCounter, msg.sender);
    }

    function createAuction(uint tokenId, uint durationMinutes, uint startPrice) external {
        require(ownerOf(tokenId) == msg.sender, "You don't own this NFT");

        auctionCounter++;
        Auction storage a = auctions[auctionCounter];
        a.tokenId = tokenId;
        a.seller = msg.sender;
        a.startPrice = startPrice;
        a.endTime = block.timestamp + durationMinutes * 1 minutes;

        transferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(tokenId, auctionCounter, a.endTime);
    }

    function placeBid(uint auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(block.timestamp < a.endTime, "Auction ended");
        require(msg.value > a.highestBid && msg.value >= a.startPrice, "Bid too low");

        if (a.highestBidder != address(0)) {
            a.bids[a.highestBidder] += a.highestBid;
        }

        a.highestBid = msg.value;
        a.highestBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function withdrawBid(uint auctionId) external {
        Auction storage a = auctions[auctionId];
        uint amount = a.bids[msg.sender];
        require(amount > 0, "No bid to withdraw");

        a.bids[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function endAuction(uint auctionId) external {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.endTime, "Auction not ended");
        require(!a.ended, "Already ended");

        a.ended = true;

        if (a.highestBidder != address(0)) {
            _transfer(address(this), a.highestBidder, a.tokenId);
            payable(a.seller).transfer(a.highestBid);
        } else {
            // No bids, return NFT to seller
            _transfer(address(this), a.seller, a.tokenId);
        }

        emit AuctionEnded(auctionId, a.highestBidder, a.highestBid);
    }

    function getAuction(uint auctionId) external view returns (
        uint tokenId,
        address seller,
        uint startPrice,
        uint highestBid,
        address highestBidder,
        uint endTime,
        bool ended
    ) {
        Auction storage a = auctions[auctionId];
        return (a.tokenId, a.seller, a.startPrice, a.highestBid, a.highestBidder, a.endTime, a.ended);
    }
}
