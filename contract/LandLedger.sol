// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Land/property registry with escrowed sales. The registrar (admin) registers verified properties;
/// owners list them; buyers pay into escrow; the owner confirms (funds released, ownership moves) or rejects (refund).
contract LandLedger {
    address public admin = msg.sender;
    uint256 public feeBps = 100; // 1% registry fee, max 5%

    struct Property { string title; string location; string size; string docHash; address owner; uint256 price; bool forSale; address buyer; uint256 escrow; uint256 registeredAt; }
    struct Transfer { address owner; uint256 price; uint256 time; }

    Property[] private props;
    mapping(uint256 => Transfer[]) private history;

    event Registered(uint256 indexed id, address indexed owner);
    event Listed(uint256 indexed id, uint256 price);
    event Delisted(uint256 indexed id);
    event OfferMade(uint256 indexed id, address indexed buyer, uint256 amount);
    event OfferCancelled(uint256 indexed id, address indexed buyer);
    event Sold(uint256 indexed id, address indexed from, address indexed to, uint256 price);

    modifier onlyAdmin() { require(msg.sender == admin, "admin only"); _; }
    modifier onlyOwner(uint256 id) { require(id < props.length, "not found"); require(props[id].owner == msg.sender, "not owner"); _; }

    function transferAdmin(address a) external onlyAdmin { require(a != address(0), "zero"); admin = a; }
    function setFee(uint256 bps) external onlyAdmin { require(bps <= 500, "max 5%"); feeBps = bps; }

    function registerProperty(address owner, string calldata title, string calldata location, string calldata size, string calldata docHash) external onlyAdmin returns (uint256 id) {
        require(owner != address(0) && bytes(title).length > 0, "invalid");
        id = props.length;
        props.push(Property(title, location, size, docHash, owner, 0, false, address(0), 0, block.timestamp));
        history[id].push(Transfer(owner, 0, block.timestamp));
        emit Registered(id, owner);
    }

    function listForSale(uint256 id, uint256 priceWei) external onlyOwner(id) {
        Property storage p = props[id];
        require(p.buyer == address(0) && priceWei > 0, "invalid");
        p.price = priceWei; p.forSale = true;
        emit Listed(id, priceWei);
    }
    function delist(uint256 id) external onlyOwner(id) {
        Property storage p = props[id];
        require(p.buyer == address(0), "offer pending");
        p.forSale = false; p.price = 0;
        emit Delisted(id);
    }

    function buy(uint256 id) external payable {
        require(id < props.length, "not found");
        Property storage p = props[id];
        require(p.forSale && p.buyer == address(0), "not available");
        require(msg.sender != p.owner && msg.value == p.price, "invalid offer");
        p.buyer = msg.sender; p.escrow = msg.value;
        emit OfferMade(id, msg.sender, msg.value);
    }
    function cancelPurchase(uint256 id) external { _refund(id, props[id].buyer == msg.sender); }
    function reject(uint256 id) external { _refund(id, props[id].owner == msg.sender); }
    function _refund(uint256 id, bool allowed) internal {
        Property storage p = props[id];
        require(allowed && p.buyer != address(0), "not allowed");
        address b = p.buyer; uint256 amt = p.escrow;
        p.buyer = address(0); p.escrow = 0;
        _send(b, amt);
        emit OfferCancelled(id, b);
    }
    function confirmSale(uint256 id) external onlyOwner(id) {
        Property storage p = props[id];
        require(p.buyer != address(0), "no offer");
        address buyer = p.buyer; uint256 amt = p.escrow; uint256 fee = amt * feeBps / 10000;
        p.owner = buyer; p.forSale = false; p.buyer = address(0); p.escrow = 0; p.price = 0;
        history[id].push(Transfer(buyer, amt, block.timestamp));
        _send(msg.sender, amt - fee);
        if (fee > 0) _send(admin, fee);
        emit Sold(id, msg.sender, buyer, amt);
    }
    function _send(address to, uint256 amt) internal { (bool ok, ) = payable(to).call{value: amt}(""); require(ok, "transfer failed"); }

    function propertyCount() external view returns (uint256) { return props.length; }
    function getProperty(uint256 id) external view returns (string memory, string memory, string memory, string memory, uint256) {
        require(id < props.length, "not found");
        Property storage p = props[id]; return (p.title, p.location, p.size, p.docHash, p.registeredAt);
    }
    function getSale(uint256 id) external view returns (address, uint256, bool, address, uint256) {
        require(id < props.length, "not found");
        Property storage p = props[id]; return (p.owner, p.price, p.forSale, p.buyer, p.escrow);
    }
    function historyCount(uint256 id) external view returns (uint256) { return history[id].length; }
    function getHistory(uint256 id, uint256 i) external view returns (address, uint256, uint256) {
        Transfer storage t = history[id][i]; return (t.owner, t.price, t.time);
    }
    function listings() external view returns (uint256[] memory out) {
        uint256 n; for (uint256 i; i < props.length; i++) if (props[i].forSale) n++;
        out = new uint256[](n); uint256 k;
        for (uint256 i; i < props.length; i++) if (props[i].forSale) out[k++] = i;
    }
    function propertiesOf(address a) external view returns (uint256[] memory out) {
        uint256 n; for (uint256 i; i < props.length; i++) if (props[i].owner == a) n++;
        out = new uint256[](n); uint256 k;
        for (uint256 i; i < props.length; i++) if (props[i].owner == a) out[k++] = i;
    }
}
