// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Hacka Token Sport - Sistema de Eventos Tokenizados
 * @dev Smart Contract NFT - Geandre Penninck
 */
contract HackaTokenSportNFT is ERC721, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;

    // ═══════════════════════ CONFIGURAÇÕES DO EVENTO ═══════════════════════
    string public constant EVENT_NAME = "Hacka Token Sport";
    string public constant VENUE = "Estadio do Morumbi - Sao Paulo";
    string public constant EVENT_DESCRIPTION = "Hacka Token Sport";
    uint256 public constant EVENT_DATE = 1767264113; // 01/01/2026 12:01:53 UTC
    uint256 public constant TICKET_PRICE = 100000000000000; // 100000 GWEI em wei
    uint256 public constant MAX_TICKETS = 30; // Total de ingressos
    address public constant EVENT_ORGANIZER = 0x9FFa7514fA7C687c411766BB63AB797c52eC6999;
    // ═══════════════════════════════════════════════════════════════════════

    struct Ticket {
        uint256 tokenId;
        uint256 purchaseDate;
        address buyer;
        bool isUsed;
        bool isValid;
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256[]) public userTickets;
    
    uint256 public soldTickets = 0;
    bool public saleActive = true;

    event TicketMinted(uint256 indexed tokenId, address indexed buyer);
    event TicketUsed(uint256 indexed tokenId, address indexed user);
    event TicketValidated(uint256 indexed tokenId, bool isValid);
    event SaleStatusChanged(bool isActive);

    modifier onlyOrganizer() {
        require(msg.sender == EVENT_ORGANIZER, "Apenas o organizador do evento");
        _;
    }

    modifier ticketExists(uint256 _tokenId) {
        require(_tokenId > 0 && _tokenId <= _tokenIds.current(), "Ingresso nao existe");
        _;
    }

    modifier saleIsActive() {
        require(saleActive, "Venda de ingressos nao esta ativa");
        _;
    }

    constructor() ERC721("HackaTokenSport", "HTS") {}

    function buyTicket() external payable nonReentrant saleIsActive returns (uint256) {
        require(soldTickets < MAX_TICKETS, "Ingressos esgotados");
        require(msg.value >= TICKET_PRICE, "Valor insuficiente");
        require(block.timestamp < EVENT_DATE, "Evento ja passou");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        tickets[newTokenId] = Ticket({
            tokenId: newTokenId,
            purchaseDate: block.timestamp,
            buyer: msg.sender,
            isUsed: false,
            isValid: true
        });

        _safeMint(msg.sender, newTokenId);

        soldTickets++;
        userTickets[msg.sender].push(newTokenId);

        payable(EVENT_ORGANIZER).transfer(msg.value);

        emit TicketMinted(newTokenId, msg.sender);
        return newTokenId;
    }

    function useTicket(uint256 _tokenId) 
        external 
        ticketExists(_tokenId) 
        onlyOrganizer 
    {
        Ticket storage ticket = tickets[_tokenId];
        require(!ticket.isUsed, "Ingresso ja foi usado");
        require(ticket.isValid, "Ingresso invalido");
        require(block.timestamp >= EVENT_DATE - 7200, "Evento ainda nao comecou");
        require(block.timestamp <= EVENT_DATE + 14400, "Evento ja terminou");

        ticket.isUsed = true;
        emit TicketUsed(_tokenId, ownerOf(_tokenId));
    }

    function invalidateTicket(uint256 _tokenId) 
        external 
        ticketExists(_tokenId) 
        onlyOrganizer 
    {
        tickets[_tokenId].isValid = false;
        emit TicketValidated(_tokenId, false);
    }

    function isTicketValid(uint256 _tokenId) external view ticketExists(_tokenId) returns (bool) {
        Ticket memory ticket = tickets[_tokenId];
        return ticket.isValid && !ticket.isUsed && saleActive && block.timestamp < EVENT_DATE;
    }

    function getTicketInfo(uint256 _tokenId) 
        external view ticketExists(_tokenId) 
        returns (Ticket memory) 
    {
        return tickets[_tokenId];
    }

    function getUserTickets(address _user) external view returns (uint256[] memory) {
        return userTickets[_user];
    }

    function getEventInfo() external pure returns (
        string memory name,
        string memory venue,
        string memory description,
        uint256 date,
        uint256 price,
        uint256 maxTickets
    ) {
        return (
            EVENT_NAME,
            VENUE,
            EVENT_DESCRIPTION,
            EVENT_DATE,
            TICKET_PRICE,
            MAX_TICKETS
        );
    }

    function getSaleStats() external view returns (
        uint256 sold,
        uint256 available,
        bool active
    ) {
        return (soldTickets, MAX_TICKETS - soldTickets, saleActive);
    }

    function setSaleStatus(bool _isActive) external onlyOrganizer {
        saleActive = _isActive;
        emit SaleStatusChanged(_isActive);
    }

    function withdraw() external onlyOrganizer {
        payable(EVENT_ORGANIZER).transfer(address(this).balance);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenId > 0 && tokenId <= _tokenIds.current(), "Token nao existe");
        
        Ticket memory ticket = tickets[tokenId];
        
        string memory status = ticket.isUsed ? "Usado" : "Valido";
        
        return string(abi.encodePacked(
            '{"name":"', EVENT_NAME, ' - Ingresso #', toString(tokenId),
            '","description":"', EVENT_DESCRIPTION,
            '","attributes":[',
                '{"trait_type":"Evento","value":"', EVENT_NAME, '"},',
                '{"trait_type":"Local","value":"', VENUE, '"},',
                '{"trait_type":"Status","value":"', status, '"}',
            ']}'
        ));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    receive() external payable {}
}
