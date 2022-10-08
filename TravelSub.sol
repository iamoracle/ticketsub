// SPDX-License-Identifier: GPL-3.0

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

pragma solidity >=0.7.0 <0.9.0;

contract TravelSub is Ownable, ERC721 {
    using ECDSA for bytes32;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _ticketsCount;

    address _account;

    IERC20 immutable _currency;

    address immutable _admin;

    enum TicketStatus {
        DEFAULT,
        SOLD,
        REDEEMED,
        CANCELLED
    }

    struct Ticket {
        uint256 id;
        uint256 issued;
        uint256 schedule;
        uint256 expires;
        uint256 price;
        uint256 origin;
        uint256 destination;
        address owner;
        TicketStatus status;
    }

    mapping(uint256 => Ticket) _tickets;

    string _uri;

    constructor(
        string memory name,
        string memory symbol,
        address currency,
        address admin,
        string memory uri
    ) ERC721(name, symbol) {
        _currency = IERC20(currency);
        _admin = admin;
        _uri = uri;
    }
    
    
    modifier valid(uint _id){
        require(_tickets[_id].id != 0, "invalid identifier");
        _;
    }

    function create_ticket(
        uint256 schedule,
        uint256 expires,
        uint256 price,
        uint16 origin,
        uint16 destination
    ) public onlyOwner {
        _tickets[_ticketsCount.current()] = Ticket(
            _ticketsCount.current(),
            block.timestamp,
            schedule,
            expires,
            price,
            origin,
            destination,
            address(0),
            TicketStatus.DEFAULT
        );
        _ticketsCount.increment();
    }

    function buy_ticket(uint256 id) public valid(id){
        Ticket storage ticket = _tickets[id];
        require(ticket.status == TicketStatus.DEFAULT, "can't buy");
        _currency.transferFrom(msg.sender, _admin, ticket.price);
        ticket.status = TicketStatus.SOLD;
        ticket.owner = msg.sender;
        safeMint(msg.sender);
    }

    // TODO: use modifiers for DRY

    function destroy_ticket(uint256 id) public onlyOwner valid(id){
        Ticket storage ticket = _tickets[id];
        require(ticket.status == TicketStatus.DEFAULT);
        ticket.status = TicketStatus.CANCELLED;
    }

    function redeem_ticket(
        uint256 id,
        bytes memory signature,
        bytes32 approvalHash
    ) public onlyOwner {
        require(
            _tickets[id].status == TicketStatus.SOLD,
            "can not redeem ticket"
        );
        require(
            _checkSignature(approvalHash, signature, _tickets[id].owner),
            "invalid signature provided"
        );

        _tickets[id].status = TicketStatus.REDEEMED;
    }

    function getApprovalHash(uint256 id) external view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), id));
    }

    function _checkSignature(
        bytes32 approvalHash,
        bytes memory signature,
        address owner
    ) private pure returns (bool) {
        bytes32 signedApprovalHash = approvalHash.toEthSignedMessageHash();
        address signer = signedApprovalHash.recover(signature);
        require(signer == owner, "invalid signature");

        return true;
    }

    function safeMint(address to) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view override virtual returns (string memory) {
        return _uri;
    }
}
