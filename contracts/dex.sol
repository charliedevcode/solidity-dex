// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./wallet.sol";

contract Dex is Wallet {
    using SafeMath for uint256;

    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint256 id;
        address trader;
        Side side;
        bytes32 ticker;
        uint256 amount;
        uint256 price;
        uint256 filled;
    }

    uint256 public nextOrderID = 0;

    mapping(bytes32 => mapping(uint256 => Order[])) public orderBook; // a mapping for buy book and for sell book

    function getOrderBook(bytes32 ticker, Side side)
        public
        view
        returns (Order[] memory)
    {
        return orderBook[ticker][uint256(side)];
    }

    function createLimitOrder(
        Side side,
        bytes32 ticker,
        uint256 amount,
        uint256 price
    ) public {
        if (side == Side.BUY) {
            require(balances[msg.sender]["ETH"] >= amount.mul(price));
        } else if (side == Side.SELL) {
            require(balances[msg.sender][ticker] >= amount);
        }

        Order[] storage orders = orderBook[ticker][uint256(side)];
        orders.push(
            Order(nextOrderID, msg.sender, side, ticker, amount, price, 0)
        );

        //bubble sort the arrays
        uint256 i = orders.length > 0 ? orders.length - 1 : 0;

        if (side == Side.BUY) {
            while (i > 0) {
                if (orders[i - 1].price > orders[i].price) {
                    break;
                }
                Order memory temp = orders[i - 1];
                orders[i - 1] = orders[i];
                orders[i] = temp;
                i--;
            }
        } else if (side == Side.SELL) {
            while (i > 0) {
                if (orders[i - 1].price < orders[i].price) {
                    break;
                }
                Order memory temp = orders[i - 1];
                orders[i - 1] = orders[i];
                orders[i] = temp;
                i--;
            }
        }
        nextOrderID++;
    }

    function createMarketOrder(
        Side side,
        bytes32 ticker,
        uint256 amount
    ) public {
        if (side == Side.SELL) {
            require(
                balances[msg.sender][ticker] >= amount,
                "Insuffient balance"
            );
        }

        uint256 orderBookSide;
        if (side == Side.BUY) {
            orderBookSide = 1;
        } else {
            orderBookSide = 0;
        }
        Order[] storage orders = orderBook[ticker][orderBookSide];

        uint256 totalFilled = 0;

        for (uint256 i = 0; i < orders.length && totalFilled < amount; i++) {
            uint256 leftToFill = amount.sub(totalFilled);
            uint256 availableToFill = orders[i].amount.sub(orders[i].filled);
            uint256 filled = 0;
            if (availableToFill > leftToFill) {
                filled = leftToFill; //Fill the entire market order
            } else {
                filled = availableToFill; //Fill as much as is available in order[i]
            }

            totalFilled = totalFilled.add(filled);
            orders[i].filled = orders[i].filled.add(filled);
            uint256 cost = filled.mul(orders[i].price);

            if (side == Side.BUY) {
                //Verify that the buyer has enough ETH to cover the purchase (require)
                require(balances[msg.sender]["ETH"] >= cost);
                //msg.sender is the buyer
                balances[msg.sender][ticker] = balances[msg.sender][ticker].add(
                    filled
                );
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].sub(
                    cost
                );

                balances[orders[i].trader][ticker] = balances[orders[i].trader][
                    ticker
                ].sub(filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader][
                    "ETH"
                ].add(cost);
            } else if (side == Side.SELL) {
                //Msg.sender is the seller
                balances[msg.sender][ticker] = balances[msg.sender][ticker].sub(
                    filled
                );
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].add(
                    cost
                );

                balances[orders[i].trader][ticker] = balances[orders[i].trader][
                    ticker
                ].add(filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader][
                    "ETH"
                ].sub(cost);
            }
        }
        //Remove 100% filled orders from the orderbook
        while (orders.length > 0 && orders[0].filled == orders[0].amount) {
            //Remove the top element in the orders array by overwriting every element
            // with the next element in the order list
            for (uint256 i = 0; i < orders.length - 1; i++) {
                orders[i] = orders[i + 1];
            }
            orders.pop();
        }
    }
}
