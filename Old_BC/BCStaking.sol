// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BillionCashStaking is Ownable {
    using SafeMath for uint256;

    uint256 public constant PERCENTS_DIVIDER = 1000;
    uint256 public constant DAILY_ROI = 15;
    uint256 public constant REFERRAL_PERCENTS = 120;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant STAKING_PERIOD = 180 days;

    ERC20 BC;

    uint256 public totalUsers;
    uint256 public totalStaked;
    uint256 public totalWithdrawn;
    uint256 public totalDepositCount;
    uint256 public minimumStakeValue = 200 * 10**18;

    struct Deposit {
        uint256 amount;
        uint256 withdrawn;
        uint256 startTime;
        uint256 endTime;
        bool ended;
    }

    struct User {
        Deposit[] deposits;
        uint256 checkpoint;
        uint256 bonus;
        uint256 referralCount;
        address referrer;
    }

    mapping(address => User) internal users;

    modifier onlyhodler() {
        require(getUserDividends(msg.sender) > 0, "Not Holder");
        _;
    }

    event Newbie(address user);
    event NewDeposit(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event onReinvestment(address indexed user, uint256 reinvestAmount);
    event RefBonus(
        address indexed referrer,
        address indexed referral,
        uint256 amount
    );

    constructor(ERC20 _token) {
        //set initial state variables
        BC = _token;
    }

    function stake(address referrer, uint256 amount) public {
        require(
            amount >= minimumStakeValue,
            "Amount is below minimum stake value."
        );

        require(
            BC.balanceOf(msg.sender) >= amount,
            "Must have enough balance to stake"
        );

        require(
            BC.transferFrom(msg.sender, address(this), amount),
            "Stake failed due to failed amount transfer."
        );

        User storage user = users[msg.sender];

        if (
            user.referrer == address(0) &&
            users[referrer].deposits.length > 0 &&
            referrer != msg.sender
        ) {
            user.referrer = referrer;
        }

        if (user.referrer != address(0)) {
            address upline = user.referrer;

            if (upline != address(0)) {
                uint256 _amount = amount.mul(REFERRAL_PERCENTS).div(
                    PERCENTS_DIVIDER
                );
                users[upline].bonus = users[upline].bonus.add(_amount);
                users[upline].referralCount = users[upline].referralCount.add(1);
                emit RefBonus(upline, msg.sender, _amount);
            }
        }

        if (user.deposits.length == 0) {
            user.checkpoint = block.timestamp;
            totalUsers = totalUsers.add(1);
            emit Newbie(msg.sender);
        }

        if (user.referrer != address(0)) {
            user.deposits.push(
                Deposit(
                    amount.sub(
                        amount.mul(REFERRAL_PERCENTS).div(PERCENTS_DIVIDER)
                    ),
                    0,
                    block.timestamp,
                    block.timestamp + STAKING_PERIOD,
                    false
                )
            );
        } else {
            user.deposits.push(
                Deposit(
                    amount,
                    0,
                    block.timestamp,
                    block.timestamp + STAKING_PERIOD,
                    false
                )
            );
        }

        totalStaked = totalStaked.add(amount);
        totalDepositCount = totalDepositCount.add(1);

        emit NewDeposit(msg.sender, amount);
    }

    function claim() public {
        User storage user = users[msg.sender];

        uint256 totalAmount;
        uint256 dividends;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            if (user.deposits[i].ended == false) {
                if (user.deposits[i].endTime > block.timestamp) {
                    if (user.deposits[i].startTime > user.checkpoint) {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(
                                block.timestamp.sub(user.deposits[i].startTime)
                            )
                            .div(TIME_STEP);
                    } else {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        ).mul(block.timestamp.sub(user.checkpoint)).div(
                                TIME_STEP
                            );
                    }
                } else {
                    if (user.deposits[i].startTime > user.checkpoint) {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(
                                user.deposits[i].endTime.sub(
                                    user.deposits[i].startTime
                                )
                            )
                            .div(TIME_STEP);
                        user.deposits[i].ended = true;
                    } else {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(user.deposits[i].endTime.sub(user.checkpoint))
                            .div(TIME_STEP);
                        user.deposits[i].ended = true;
                    }
                }

                user.deposits[i].withdrawn = user.deposits[i].withdrawn.add(
                    dividends
                ); /// changing of storage data
                totalAmount = totalAmount.add(dividends);
            }
        }

        uint256 referralBonus = getUserReferralBonus(msg.sender);
        if (referralBonus > 0) {
            totalAmount = totalAmount.add(referralBonus);
            user.bonus = 0;
            user.referralCount = 0;
        }

        require(totalAmount > 0, "User has no dividends");

        uint256 contractBalance = BC.balanceOf(address(this));
        if (contractBalance < totalAmount) {
            totalAmount = contractBalance;
        }

        user.checkpoint = block.timestamp;

        require(
            BC.transfer(msg.sender, totalAmount),
            "Claim failed due to failed amount transfer."
        );

        totalWithdrawn = totalWithdrawn.add(totalAmount);

        emit Withdrawn(msg.sender, totalAmount);
    }

    function compound() public onlyhodler {
        User storage user = users[msg.sender];
        // fetch dividends
        uint256 _dividends = getUserDividends(msg.sender); // retrieve ref. bonus later in the code
        uint256 totalAmount;
        uint256 dividends;

        user.deposits.push(
            Deposit(
                _dividends,
                0,
                block.timestamp,
                block.timestamp + STAKING_PERIOD,
                false
            )
        );

        for (uint256 i = 0; i < user.deposits.length; i++) {
            if (user.deposits[i].ended == false) {
                if (user.deposits[i].endTime > block.timestamp) {
                    if (user.deposits[i].startTime > user.checkpoint) {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(
                                block.timestamp.sub(user.deposits[i].startTime)
                            )
                            .div(TIME_STEP);
                    } else {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        ).mul(block.timestamp.sub(user.checkpoint)).div(
                                TIME_STEP
                            );
                    }
                } else {
                    if (user.deposits[i].startTime > user.checkpoint) {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(
                                user.deposits[i].endTime.sub(
                                    user.deposits[i].startTime
                                )
                            )
                            .div(TIME_STEP);
                        user.deposits[i].ended = true;
                    } else {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(user.deposits[i].endTime.sub(user.checkpoint))
                            .div(TIME_STEP);
                        user.deposits[i].ended = true;
                    }
                }

                user.deposits[i].withdrawn = user.deposits[i].withdrawn.add(
                    dividends
                ); /// changing of storage data
                totalAmount = totalAmount.add(dividends);
            }
        }

        user.checkpoint = block.timestamp;

        totalStaked = totalStaked.add(_dividends);
        totalDepositCount = totalDepositCount.add(1);
        totalWithdrawn = totalWithdrawn.add(totalAmount);
        // fire event
        emit onReinvestment(msg.sender, _dividends);
    }

    function getUserDividends(address userAddress)
        public
        view
        returns (uint256)
    {
        User storage user = users[userAddress];

        uint256 totalDividends;
        uint256 dividends;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            if (user.deposits[i].ended == false) {
                if (user.deposits[i].endTime > block.timestamp) {
                    if (user.deposits[i].startTime > user.checkpoint) {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(
                                block.timestamp.sub(user.deposits[i].startTime)
                            )
                            .div(TIME_STEP);
                    } else {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        ).mul(block.timestamp.sub(user.checkpoint)).div(
                                TIME_STEP
                            );
                    }
                } else {
                    if (user.deposits[i].startTime > user.checkpoint) {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(
                                user.deposits[i].endTime.sub(
                                    user.deposits[i].startTime
                                )
                            )
                            .div(TIME_STEP);
                    } else {
                        dividends = (
                            user.deposits[i].amount.mul(DAILY_ROI).div(
                                PERCENTS_DIVIDER
                            )
                        )
                            .mul(user.deposits[i].endTime.sub(user.checkpoint))
                            .div(TIME_STEP);
                    }
                }
                totalDividends = totalDividends.add(dividends);
            }
        }

        return totalDividends;
    }

    function getUserReferralBonus(address userAddress)
        public
        view
        returns (uint256)
    {
        return users[userAddress].bonus;
    }

    function getUserReferralCount(address userAddress)
        public
        view
        returns (uint256)
    {
        return users[userAddress].referralCount;
    }

    function getUserReferrer(address userAddress)
        public
        view
        returns (address)
    {
        return users[userAddress].referrer;
    }

    function getUserCheckpoint(address userAddress)
        public
        view
        returns (uint256)
    {
        return users[userAddress].checkpoint;
    }

    function getUserAvailable(address userAddress)
        public
        view
        returns (uint256)
    {
        return
            getUserReferralBonus(userAddress).add(
                getUserDividends(userAddress)
            );
    }

    function getUserDepositInfo(address userAddress, uint256 index)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        User storage user = users[userAddress];

        return (
            user.deposits[index].amount,
            user.deposits[index].withdrawn,
            user.deposits[index].startTime,
            user.deposits[index].endTime,
            user.deposits[index].ended
        );
    }

    function getUserAmountOfDeposits(address userAddress)
        public
        view
        returns (uint256)
    {
        return users[userAddress].deposits.length;
    }

    function getUserTotalDeposits(address userAddress)
        public
        view
        returns (uint256)
    {
        User storage user = users[userAddress];

        uint256 amount;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            if (user.deposits[i].ended == false) {
                amount = amount.add(user.deposits[i].amount);
            }
        }

        return amount;
    }

    function getUserTotalWithdrawn(address userAddress)
        public
        view
        returns (uint256)
    {
        User storage user = users[userAddress];

        uint256 amount;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            amount = amount.add(user.deposits[i].withdrawn);
        }

        return amount;
    }

    //sets the minimum stake value
    function setMinimumStakeValue(uint256 _minimumStakeValue)
        external
        onlyOwner
    {
        minimumStakeValue = _minimumStakeValue;
    }
}
