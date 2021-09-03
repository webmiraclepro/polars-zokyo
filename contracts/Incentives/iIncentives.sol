pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

interface IIncentives {
    
    event IncentivesTokenCreated(string indexed symbol, address indexed contractAddress);
    /**
    Put governance tokens into this contract
    */
    function putGovernance(uint256 amount) external; 
    
    /**
     * Withdraw Governance tokens.
     */
     function withdrawGovernance(uint amount) external;
    
    /**
     * Withdraw some amount of specific incentives token.
     * @param tokenAddress address of incentives token user wants to withdraw.
    */
    function withdrawIncentives(address tokenAddress, uint amount) external;
    
    /**
     * Return incentives tokens to the contract.
     */
     function putIncentivesTokens(address tokenAddress, uint amount) external;
     
     /**
      * Create new incentives token.
      */
     function createnNewIncentivesToken(string memory name, string memory symbol) external;
     
     /**
      * Switch to the new contract owner.
      */
      function switchOwner(address newOwner) external;

     /**
      * function returns user tokens state. how many different tokens contract holds
      * for the user including Governance tokens.
      * @return list of token addresses and their respective amounts list including governance token.
      */
      function userState(address _user) view external returns(address[] memory, uint256[] memory);
      
       /**
      * function returns all available tokens on the contract
      * @return list of token addresses and their respective amounts list including governance token.
      */
      function availableTokens() view external returns(address[] memory, uint256[] memory);
      
      /**
       * Function returns count of unique users with governance tokens in the contract.
       */
       function userscount() view external returns(uint256);
       /**
       * Compute the address of the contract to be deployed.
       */
       function getAddress(string memory name, string memory symbol) view external returns (address);

       function getMaxBorrowed(address user) view external returns(uint256);
       function getGovBalances(address user) view external returns(uint256);
       function setCrowdsale(address crowdsale) external;
       function lockGovernance(address lockContract,address incentivesToken,uint256 amount,uint256 unlock_time) external;
    
}
