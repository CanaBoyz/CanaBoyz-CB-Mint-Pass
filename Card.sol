// SPDX-License-Identifier: MIT
/// @author KRogLA (https://github.com/krogla)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "./lib/errors.sol";

error MaxUsesCountReached();
error MaxOwnsCountReached();
error ZeroUseCount();

/**
 * @dev {ERC721} base card template
 */
contract Card is
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event Used(uint256 tokenId, uint256 remainUses);

    struct CardMeta {
        uint128 uses;
        uint128 level;
    }

    string private _baseTokenURI;
    uint256 private _tokenIdTracker;
    uint128 private _maxOwnsCount;
    uint128 private _maxUsesCount;
    // Mapping from token ID to token meta
    mapping(uint256 => CardMeta) private _meta;
    // level id = levelUri
    mapping(uint128 => string) private _levelURIs;

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint128 ownsCount,
        uint128 usesCount
    ) external initializer {
        __Card_init(name, symbol, baseTokenURI, ownsCount, usesCount);
    }

    function __Card_init(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint128 ownsCount,
        uint128 usesCount
    ) internal onlyInitializing {
        __Pausable_init_unchained();
        __ERC721_init_unchained(name, symbol);
        __Card_init_unchained(baseTokenURI, ownsCount, usesCount);
    }

    function __Card_init_unchained(
        string memory baseTokenURI,
        uint128 ownsCount,
        uint128 usesCount
    ) internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());

        _baseTokenURI = baseTokenURI;
        _maxOwnsCount = ownsCount;
        _maxUsesCount = usesCount;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        string memory _levelURI = _levelURIs[_meta[tokenId].level];
        if (bytes(_levelURI).length == 0) {
            return super.tokenURI(tokenId);
        }

        if (bytes(_baseTokenURI).length == 0) {
            return _levelURI;
        }

        return string(abi.encodePacked(_baseTokenURI, _levelURI));
    }

    /**
     * @dev See {ERC721-_baseURI}.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Return base token URI
     */
    function baseURI() external view returns (string memory) {
        return _baseURI();
    }

    /**
     * @dev Set new base URI. See {ERC721-_baseURI}.
     */
    function setBaseURI(string memory baseTokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseTokenURI;
    }

    function getLevelURI(uint128 levelId) external view returns (string memory) {
        return _levelURIs[levelId];
    }

    function setLevelURI(uint128 levelId, string memory levelURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _levelURIs[levelId] = levelURI;
    }

    function setLevelURIs(uint128[] memory levelIds, string[] memory levelURIs) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (levelIds.length == 0 || levelIds.length != levelURIs.length) revert WrongInputParams();
        for (uint256 i = 0; i < levelIds.length; i++) {
            _levelURIs[levelIds[i]] = levelURIs[i];
        }
    }

    /**
     * @dev Get max owns count.
     */
    function maxOwns() external view returns (uint256) {
        return _maxOwnsCount;
    }

    /**
     * @dev Get max uses count.
     */
    function maxUses() external view returns (uint256) {
        return _maxUsesCount;
    }

    /**
     * @dev Creates a new token with default uri
     */
    function mint(address to, uint128 level) external onlyRole(MINTER_ROLE) {
        _mint(to, _tokenIdTracker);
        _meta[_tokenIdTracker].level = level;
        _tokenIdTracker++;
    }

    /**
     * @dev Creates a batch of new tokens with default uri
     */
    function mintBatch(
        address[] memory tos,
        uint128[] memory levels
    ) external onlyRole(MINTER_ROLE) {
        if (tos.length != levels.length) revert WrongInputParams();
        for (uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], _tokenIdTracker);
            _meta[_tokenIdTracker].level = levels[i];
            _tokenIdTracker++;
        }
    }

    function _burn(uint256 tokenId) internal override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert CallerIsNotOwnerNorApproved();
        super._burn(tokenId);
        // clean state
        delete _meta[tokenId];
    }

    /**
     * @dev Destroys `tokenId`. See {ERC721-_burn}.
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function burnBatch(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
    }

    /**
     * @dev Batch transfer
     */
    function transferFromBatch(
        address from,
        address to,
        uint256[] memory tokenIds
    ) external virtual {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * @dev Increment uses count for card with specified ID.
     */
    function useCard(uint256 tokenId, uint128 count) external onlyRole(OPERATOR_ROLE) returns (CardMeta memory meta) {
        if (!_exists(tokenId)) revert NotExists();
        if (count == 0) revert ZeroUseCount();
        meta = _meta[tokenId];
        if (meta.uses + count > _maxUsesCount) revert MaxUsesCountReached();
        meta.uses += count;
        //save uses count
        _meta[tokenId].uses = meta.uses;
        emit Used(tokenId, _maxUsesCount - meta.uses);
        return meta;
    }

    /**
     * @dev Increment uses count for card for specific owner.
     */
    function useCardFrom(address owner, uint128 count)
        external
        onlyRole(OPERATOR_ROLE)
        returns (
            uint256 tokenId,
            CardMeta memory meta,
            uint128 maxUsesCount
        )
    {
        if (count == 0) revert ZeroUseCount();
        uint256 cardsCount = balanceOf(owner);
        if (cardsCount == 0) revert NotExists();
        maxUsesCount = _maxUsesCount;
        for (uint256 i = 0; i < cardsCount; i++) {
            tokenId = tokenOfOwnerByIndex(owner, i);
            meta = _meta[tokenId];
            if (meta.uses + count <= maxUsesCount) {
                meta.uses += count;
                //save uses count
                _meta[tokenId].uses = meta.uses;
                emit Used(tokenId, _maxUsesCount - meta.uses);
                return (tokenId, meta, maxUsesCount);
                // break;
            }
        }
        revert MaxUsesCountReached();
    }

    /**
     * @dev Get card uses count
     */
    function cardUses(uint256 tokenId) external view returns (uint128) {
        if (!_exists(tokenId)) revert NotExists();
        return _meta[tokenId].uses;
    }

    function cardUsesOf(address owner) external view returns (uint128 uses) {
        uint256 cardsCount = balanceOf(owner);
        if (cardsCount == 0) revert NotExists();
        for (uint256 i = 0; i < cardsCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            uses += _meta[tokenId].uses;
        }
    }

    function canUseCardFrom(address owner, uint128 count) external view returns (bool) {
        if (count == 0) revert ZeroUseCount();
        uint256 cardsCount = balanceOf(owner);
        if (cardsCount == 0) revert NotExists();
        uint256 tokenId;
        CardMeta memory meta;
        for (uint256 i = 0; i < cardsCount; i++) {
            tokenId = tokenOfOwnerByIndex(owner, i);
            meta = _meta[tokenId];
            if (meta.uses + count <= _maxUsesCount) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Get card level
     */
    function cardLevel(uint256 tokenId) external view returns (uint128) {
        if (!_exists(tokenId)) revert NotExists();
        return _meta[tokenId].level;
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(IERC721Upgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return hasRole(OPERATOR_ROLE, operator) || super.isApprovedForAll(owner, operator);
    }

    //// PAUSABLE
    /**
     * @dev Pauses all token transfers.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
        if (paused()) revert TransferWhilePaused();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721EnumerableUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {UUPS-_authorizeUpgrade}. Allows `DEFAULT_ADMIN_ROLE` to perform upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override(UUPSUpgradeable) {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
}
