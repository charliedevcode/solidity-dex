// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Link is ERC20 {
    constructor() ERC20("Chainlink", "LINK") {
        ERC20._mint(msg.sender, 100000);
    }
}