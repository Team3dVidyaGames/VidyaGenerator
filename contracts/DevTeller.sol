// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IVault.sol";

/**
 * @title Dev Teller Contract
 */
contract DevTeller is Ownable, ReentrancyGuard {
    using Address for address;

    /// @notice Event emitted only on construction.
    event TellerDeployed();

    /// @notice Event emitted when teller toggled.
    event TellerToggled(address teller, bool status);

    /// @notice Event emitted when provider claimed.
    event Claimed(address provider, bool success);

    /// @notice Event emitted when a new developer is added
    event newDeveloper(address developer);

    /// @notice Event emitted when a developer is removed
    event devRemoved(address developer);

    /// @notice Event emitted when
    event weightChanged(address developer, uint256 weight);



    IVault Vault;

    
    struct Developer{

        uint256 weight;
        uint256 lastClaim;
        uint256 isDeveloper;

    }

    mapping(address=> Developer) developers;
    uint256 totalWeight;
    uint256 tellerClosedTime;

    bool tellerOpen;

    modifier isTellerOpen() {
        require(tellerOpen, "Teller: Teller is not opened.");
        _;
    }

    modifier isDeveloper() {
        require(
            developers[msg.sender].isDeveloper,
            "Teller: Caller is not a developer."
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _LpToken Interface of LP token
     * @param _Vault Interface of Vault
     */
    constructor( IVault _Vault) {

        Vault = _Vault;

        emit TellerDeployed();
    }

    /**
     * @dev External function to toggle the teller. This function can be called by only owner.
     */
    function toggleTeller() external onlyOwner {
        if (!(tellerOpen = !tellerOpen)) {
            tellerClosedTime = block.timestamp;
        }

        emit TellerToggled(address(this), tellerOpen);
    }


    function addDeveloper(address _dev, uint256 _weight) onlyOwner isTellerOpen{
        require(!developers[_dev].isDeveloper, "Teller: Already a developer");

        developers[_dev].weight = _weight;
        developers[_dev].lastClaim = block.timestamp;
        developers[_dev].isDeveloper = true;
        totalWeight += _weight;
        emit newDeveloper(_dev)
    }

    function changeDeveloperWeight(address _dev, uint256 _weight, bool add_Subtract) onlyOwner{
        
        require(developers[_dev].isDeveloper, "Teller: Not currently a developer");
        Developer storage dev = developers[_dev];
        claim(_dev);
        if(add_Subtract){
            dev.weight += _weight;
            totalWeight += _weight;
        }else{
            if(dev.weight > _weight){
                dev.weight -= _weight;
                totalWeight -= _weight;
            }else{
                totalWeight -= dev.weight;
                dev.weight =0;
                dev.isDeveloper = false;
                emit devRemoved(_dev);
            }
        }
        emit weightChanged(_dev, developers[_dev].weight);
    }

    function removeDeveloper(address _dev) onlyOwner{

        require(developers[_dev].isDeveloper, "Teller: Not currently a developer");
        claim(_dev);
        Developer storage dev = developers[_dev];
        totalWeight -= dev.weight;
        dev.weight = 0;
        dev.isDeveloper = false;

        emit devRemoved(_dev);


    }



    function claim(address _dev) private{
        Developer storage dev = developers[_dev];

        uint256 timeGap = block.timestamp - dev.lastClaim;

        if (!tellerOpen) {
            timeGap = tellerClosedTime - dev.lastClaim;
        }

        uint256 timeWeight = timeGap * dev.Weight;

        dev.lastClaim = block.timestamp;

        Vault.payProvider(_dev, timeWeight, totalWeight);

        emit Claimed(_dev, true);
    }

    /**
     * @dev External function to claim the vidya token. This function can be called by only developer and teller must be opened.
     */
    function externalClaim() external isDeveloper nonReentrant{
        claim(msg.sender);
    }

}
