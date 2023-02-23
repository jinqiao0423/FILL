// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";

import "./Utils/Context.sol";
import "./Utils/Validation.sol";
import "./FLE.sol";

interface FILLInterface {
    struct BorrowInfo {
        uint256 id; // borrow id
        address account; //borrow account
        uint256 amount; //borrow amount
        bytes minerAddr; //miner
        uint256 interestRate; // interest rate
        uint256 borrowTime; // borrow time
        uint256 paybackTime; // payback time
        bool isPayback; // flag for status
    }
    struct MinerBorrowInfo {
        bytes minerAddr; //miner
        BorrowInfo[] borrows;
    }
    struct MinerStakingInfo {
        bytes minerAddr;
        uint256 quota;
        uint256 borrowCount;
        uint256 paybackCount;
        uint64 expiration;
    }
    struct FILLInfo {
        uint256 availableFIL; // a.	Available FIL Liquidity a=b+d-c
        uint256 totalDeposited; // b.	Total Deposited Liquidity
        uint256 utilizedLiquidity; // c.	Current Utilized Liquidity c=b+d-a
        uint256 accumulatedInterest; // d.	Accumulated Interest Payment Received
        uint256 accumulatedPayback; // e.	Accumulated Repayments
        uint256 accumulatedRedeem; // f.	Accumulated FIL Redemptions
        uint256 accumulatedBurnFLE; // g.	Accumulated FLE Burnt
        uint256 utilizationRate; // h.	Current Utilization Rate  h=c/(b+d-e)
        uint256 exchangeRate; // i.	Current FLE/FIL Exchange Rate
        uint256 interestRate; // j.	Current Interest Rate
        uint256 totalFee; // k.	Total Transaction Fee Received
    }

    /// @dev deposit FIL to the contract, mint FLE
    /// @param amountFIL  the amount of FIL user would like to deposit
    /// @param exchangeRate approximated exchange rate at the point of request
    /// @param slippageTolr slippage tolerance
    /// @return amount actual FLE minted
    function deposit(
        uint256 amountFIL,
        uint256 exchangeRate,
        uint256 slippageTolr
    ) external payable returns (uint256 amount);

    /// @dev redeem FLE to the contract, withdraw FIL
    /// @param amountFLE the amount of FLE user would like to redeem
    /// @param exchangeRate approximated exchange rate at the point of request
    /// @param slippageTolr slippage tolerance
    /// @return amount actual FIL withdrawal
    function redeem(
        uint256 amountFLE,
        uint256 exchangeRate,
        uint256 slippageTolr
    ) external returns (uint256 amount);

    /// @dev borrow FIL from the contract
    /// @param minerAddr miner address
    /// @param amountFIL the amount of FIL user would like to borrow
    /// @param interestRate approximated interest rate at the point of request
    /// @param slippageTolr slippage tolerance
    /// @return amount actual FIL borrowed
    function borrow(
        bytes memory minerAddr,
        uint256 amountFIL,
        uint256 interestRate,
        uint256 slippageTolr
    ) external returns (uint256 amount);

    /// @dev payback principal and interest
    /// @param minerAddr miner address
    /// @param borrowId borrow id
    /// @return amount actual FIL repaid
    function payback(bytes memory minerAddr, uint256 borrowId)
        external
        returns (uint256 amount);

    /// @dev staking miner : change beneficiary to contract , need owner for miner propose change beneficiary first
    /// @param minerAddr miner address
    /// @return flag result flag for change beneficiary
    function stakingMiner(bytes memory minerAddr) external returns (bool);

    /// @dev unstaking miner : change beneficiary back to miner owner, need payback all first
    /// @param minerAddr miner address
    /// @return flag result flag for change beneficiary
    function unstakingMiner(bytes memory minerAddr) external returns (bool);

    /// @dev FLE balance of a user
    /// @param account user account
    /// @return balance user’s FLE account balance
    function fleBalanceOf(address account)
        external
        view
        returns (uint256 balance);

    /// @dev user’s borrowing information
    /// @param account user’s account address
    /// @return infos user’s borrowing informations
    function userBorrows(address account)
        external
        view
        returns (MinerBorrowInfo[] memory infos);

    /// @dev get staking miner info : minerAddr,quota,borrowCount,paybackCount,expiration
    /// @param minerAddr miner address
    /// @return info return staking miner info
    function getStakingMinerInfo(bytes memory minerAddr)
        external
        view
        returns (MinerStakingInfo memory);

    /// @dev FLE token address
    function fleAddress() external view returns (address);

    /// @dev Validation contract address
    function validationAddress() external view returns (address);

    /// @dev return FIL/FLE exchange rate: total amount of FIL liquidity divided by total amount of FLE outstanding
    function exchangeRate() external view returns (uint256);

    /// @dev return transaction fee rate
    function feeRate() external view returns (uint256);

    /// @dev return borrowing interest rate : a mathematical function of utilizatonRate
    function interestRate() external view returns (uint256);

    /// @dev return liquidity pool utilization : the amount of FIL being utilized divided by the total liquidity provided (the amount of FIL deposited and the interest repaid)
    function utilizationRate() external view returns (uint256);

    /// @dev return fill contract infos
    function fillInfo() external view returns (FILLInfo memory);

    /// @dev Emitted when `account` deposits `amountFIL` and mints `amountFLE`
    event Deposit(
        address indexed account,
        uint256 amountFIL,
        uint256 amountFLE
    );
    /// @dev Emitted when `account` redeems `amountFLE` and withdraws `amountFIL`
    event Redeem(address indexed account, uint256 amountFLE, uint256 amountFIL);
    /// @dev Emitted when user `account` borrows `amountFIL` with `minerId`
    event Borrow(
        uint256 indexed id,
        address indexed account,
        bytes indexed minerAddr,
        uint256 amountFIL
    );
    /// @dev Emitted when user `account` repays `amount` FIL with `minerId`
    event Payback(
        uint256 indexed id,
        address indexed account,
        bytes indexed minerAddr,
        uint256 amountFIL
    );

    // / @dev Emitted when staking `minerAddr` : change beneficiary to `beneficiary` with info `quota`,`expiration`
    event StakingMiner(
        bytes minerAddr,
        bytes beneficiary,
        uint256 quota,
        uint64 expiration
    );
    // / @dev Emitted when unstaking `minerAddr` : change beneficiary to `beneficiary` with info `quota`,`expiration`
    event UnstakingMiner(
        bytes minerAddr,
        bytes beneficiary,
        uint256 quota,
        uint64 expiration
    );
}

contract FILL is Context, FILLInterface {
    mapping(bytes => BorrowInfo[]) public minerBorrows;
    mapping(address => bytes[]) public userMiners;
    mapping(bytes => address) private minerBindsMap;
    mapping(bytes => MinerStakingInfo) private minerStaking;

    address private _owner;
    uint256 private _accumulatedDepositFIL;
    uint256 private _accumulatedRedeemFIL;
    uint256 private _accumulatedBorrowFIL;
    uint256 private _accumulatedPaybackFIL;
    uint256 private _accumulatedInterestFIL;
    uint256 private _totalFee;

    uint256 constant DEFAULT_RATE_BASE = 1000000;
    uint256 private _feeRate; // fee=_feeRate/DEFAULT_RATE_BASE
    uint256 private _exchangeRate; // FIL/FLE=_exchangeRate/DEFAULT_RATE_BASE
    uint256 private _interestRate; // interestRate=_interestRate/DEFAULT_RATE_BASE
    uint256 private _utilizationRate; //
    FLE _tokenFLE;
    Validation _validation;

    constructor(address fleAddr, address validationAddr) {
        _tokenFLE = FLE(fleAddr);
        _validation = Validation(validationAddr);
        _owner = _msgSender();
        _feeRate = 1000;
        _exchangeRate = DEFAULT_RATE_BASE;
        _interestRate = 43400;
    }

    function deposit(
        uint256 amountFIL,
        uint256 exchRate,
        uint256 slippage
    ) external payable returns (uint256) {
        checkExchangeRate(exchRate, slippage);
        require(msg.value == amountFIL, "value not match");
        uint256 amountFLE = (amountFIL * DEFAULT_RATE_BASE) / _exchangeRate;
        _tokenFLE.mint(_msgSender(), amountFLE);

        _accumulatedDepositFIL += amountFIL;
        emit Deposit(_msgSender(), amountFIL, amountFLE);

        return amountFLE;
    }

    function redeem(
        uint256 amountFLE,
        uint256 exchRate,
        uint256 slippage
    ) external returns (uint256) {
        checkExchangeRate(exchRate, slippage);
        _tokenFLE.burn(_msgSender(), amountFLE);
        uint256 amountFIL = (amountFLE * _exchangeRate) / DEFAULT_RATE_BASE;
        payable(_msgSender()).transfer(amountFIL);
        _accumulatedRedeemFIL += amountFIL;

        emit Redeem(_msgSender(), amountFLE, amountFIL);
        return amountFIL;
    }

    function borrow(
        bytes memory minerAddr,
        uint256 amount,
        uint256 interest_rate,
        uint256 slippage
    ) external returns (uint256) {
        haveStaking(minerAddr);
        isBindMiner(_msgSender(), minerAddr);
        checkInterestRate(interest_rate, slippage);
        require(
            (amount + minerStaking[minerAddr].borrowCount) <
                minerStaking[minerAddr].quota,
            "not enough to borrow"
        );
        // add a borrow
        BorrowInfo[] storage borrows = minerBorrows[minerAddr];
        borrows.push(
            BorrowInfo({
                id: borrows.length,
                account: _msgSender(),
                amount: amount,
                minerAddr: minerAddr,
                interestRate: interest_rate,
                borrowTime: block.timestamp,
                paybackTime: 0,
                isPayback: false
            })
        );
        minerStaking[minerAddr].borrowCount += amount;
        _accumulatedBorrowFIL += amount;
        // send fil to miner
        SendAPI.send(minerAddr, amount);

        emit Borrow(borrows.length - 1, _msgSender(), minerAddr, amount);
        return amount;
    }

    function payback(bytes memory minerAddr, uint256 borrowId)
        external
        returns (uint256)
    {
        require(minerAddr.length != 0, "invalid miner address");
        BorrowInfo storage info = minerBorrows[minerAddr][borrowId];
        require(
            uint256(bytes32(info.minerAddr)) == uint256(bytes32(minerAddr)),
            "invalid borrowId"
        );
        require(info.isPayback == false, "no need payback");
        // calc interest
        uint256 borrowingPeriod = 0; // todo : 0 only for dev
        uint256 interest = (info.amount * borrowingPeriod) /
            _interestRate;
        uint256 paybackAmount = info.amount + interest;

        // pay back use miner withdraw
        MinerAPI.withdrawBalance(
            minerAddr,
            MinerTypes.WithdrawBalanceParams({
                amount_requested: abi.encodePacked(bytes32(paybackAmount))
            })
        );
        _accumulatedPaybackFIL += info.amount;
        _accumulatedInterestFIL += interest;

        minerStaking[minerAddr].paybackCount += info.amount;

        info.paybackTime = block.timestamp;
        info.isPayback = true;

        emit Payback(borrowId, _msgSender(), minerAddr, paybackAmount);

        return paybackAmount;
    }

    function bindMiner(
        bytes memory minerAddr,
        bytes memory signature
    ) external returns (bool) {
        if (minerBindsMap[minerAddr] == address(0)) {
            address sender = _msgSender();
            _validation.validateOwner(minerAddr, signature, sender);
            minerBindsMap[minerAddr] = sender;
            userMiners[sender].push(minerAddr);
            return true;
        } else {
            return false;
        }
    }

    function unbindMiner(bytes memory minerAddr) external returns (bool) {
        address sender = _msgSender();
        isBindMiner(sender, minerAddr);
        delete minerBindsMap[minerAddr];
        bytes[] storage miners = userMiners[sender];
        for (uint256 i = 0; i < miners.length; i++) {
            if (uint256(bytes32(miners[i])) == uint256(bytes32(minerAddr))) {
                if (i != miners.length - 1) {
                    miners[i] = miners[miners.length - 1];
                }
                miners.pop();
                break;
            }
        }
        return true;
    }

    function stakingMiner(bytes memory minerAddr) external returns (bool) {
        noStaking(minerAddr);
        isBindMiner(_msgSender(), minerAddr);
        // get propose for change beneficiary
        CommonTypes.PendingBeneficiaryChange memory proposedBeneficiaryRet = MinerAPI
            .getBeneficiary(minerAddr).proposed;

        // todo : check new_beneficiary

        // new_quota check
        uint256 quota = uint256(
            bytes32(
                BigIntCBOR.serializeBigInt(proposedBeneficiaryRet.new_quota)
            )
        );
        require(quota > 0, "need quota > 0");
        require(
            proposedBeneficiaryRet.new_expiration > block.number,
            "expiration invalid"
        );

        // change beneficiary to contract
        MinerAPI.changeBeneficiary(
            minerAddr,
            MinerTypes.ChangeBeneficiaryParams({
                new_beneficiary: proposedBeneficiaryRet.new_beneficiary,
                new_quota: proposedBeneficiaryRet.new_quota,
                new_expiration: proposedBeneficiaryRet.new_expiration
            })
        );

        //  todo : check beneficiary again ?

        // add minerStaking
        minerStaking[minerAddr] = MinerStakingInfo({
            minerAddr: minerAddr,
            quota: quota,
            borrowCount: 0,
            paybackCount: 0,
            expiration: proposedBeneficiaryRet.new_expiration
        });

        emit StakingMiner(
            minerAddr,
            proposedBeneficiaryRet.new_beneficiary,
            quota,
            proposedBeneficiaryRet.new_expiration
        );
        return true;
    }

    function unstakingMiner(bytes memory minerAddr) external returns (bool) {
        haveStaking(minerAddr);
        isBindMiner(_msgSender(), minerAddr);
        require(
            minerStaking[minerAddr].borrowCount ==
                minerStaking[minerAddr].paybackCount,
            "payback first"
        );

        // change Beneficiary to owner
        bytes memory owner = MinerAPI.getOwner(
            minerAddr
        ).owner;
        bytes memory beneficiary = MinerAPI
            .getBeneficiary(minerAddr).active.beneficiary;
        if (
            uint256(bytes32(beneficiary)) !=
            uint256(bytes32(owner))
        ) {
            MinerAPI.changeBeneficiary(
                minerAddr,
                MinerTypes.ChangeBeneficiaryParams({
                    new_beneficiary: owner,
                    new_quota: BigInt(hex"00", false),
                    new_expiration: 0
                })
            );
        }

        delete minerStaking[minerAddr];
        emit UnstakingMiner(minerAddr, owner, 0, 0);

        return true;
    }

    function fleBalanceOf(address account) external view returns (uint256) {
        return _tokenFLE.balanceOf(account);
    }

    function userBorrows(address account)
        external
        view
        returns (MinerBorrowInfo[] memory) 
    {
        MinerBorrowInfo[] memory result = new MinerBorrowInfo[](userMiners[account].length);
        for (uint256 i = 0; i < result.length; i++) {
            bytes storage minerAddr = userMiners[account][i];
            result[i].minerAddr = minerAddr;
            result[i].borrows = minerBorrows[minerAddr];
        }
        return result;
    }

    function getStakingMinerInfo(bytes memory minerAddr)
        external
        view
        returns (MinerStakingInfo memory)
    {
        return minerStaking[minerAddr];
    }

    function fillInfo() external view returns (FILLInfo memory) {
        return
            FILLInfo({
                availableFIL: (_accumulatedDepositFIL +
                    _accumulatedInterestFIL -
                    (_accumulatedBorrowFIL - _accumulatedPaybackFIL)),
                totalDeposited: _accumulatedDepositFIL,
                utilizedLiquidity: (_accumulatedBorrowFIL -
                    _accumulatedPaybackFIL),
                accumulatedInterest: _accumulatedInterestFIL,
                accumulatedPayback: _accumulatedPaybackFIL,
                accumulatedRedeem: _accumulatedRedeemFIL,
                accumulatedBurnFLE: _accumulatedRedeemFIL,
                utilizationRate: _utilizationRate,
                exchangeRate: _exchangeRate,
                interestRate: _interestRate,
                totalFee: _totalFee
            });
    }

    function fleAddress() external view returns (address) {
        return address(_tokenFLE);
    }

    function validationAddress() external view returns (address) {
        return address(_validation);
    }

    function exchangeRate() external view returns (uint256) {
        return _exchangeRate;
    }

    // todo : remove it later
    function setExchangeRate(uint64 newRate)
        public
        onlyOwner
        returns (uint256)
    {
        _exchangeRate = newRate;
        return _exchangeRate;
    }

    function feeRate() external view returns (uint256) {
        return _feeRate;
    }

    function setFeeRate(uint64 newRate) external onlyOwner returns (uint256) {
        _feeRate = newRate;
        return _feeRate;
    }

    function utilizationRate() external view returns (uint256) {
        return _utilizationRate;
    }

    function interestRate() external view returns (uint256) {
        return _interestRate;
    }

    function setInterestRate(uint64 newRate)
        external
        onlyOwner
        returns (uint256)
    {
        _interestRate = newRate;
        return _interestRate;
    }

    // ------------------ function only for dev ------------------begin
    function send(address account, uint256 amount) external onlyOwner {
        payable(account).transfer(amount);
    }

    function devManage(
        uint256 code,
        bytes memory minerAddress,
        uint256 amount
    ) external onlyOwner {
        if (code == 1) {
            // confirmBeneficiary
            MinerTypes.GetBeneficiaryReturn memory beneficiaryRet = MinerAPI
                .getBeneficiary(minerAddress);
            MinerAPI.changeBeneficiary(
                minerAddress,
                MinerTypes.ChangeBeneficiaryParams({
                    new_beneficiary: beneficiaryRet.proposed.new_beneficiary,
                    new_quota: beneficiaryRet.proposed.new_quota,
                    new_expiration: beneficiaryRet.proposed.new_expiration
                })
            );
        } else if (code == 2) {
            MinerAPI.withdrawBalance(
                minerAddress,
                MinerTypes.WithdrawBalanceParams({
                    amount_requested: abi.encodePacked(bytes32(amount))
                })
            );
        } else if (code == 3) {
            // change Beneficiary to owner
            MinerTypes.GetOwnerReturn memory minerInfo = MinerAPI.getOwner(
                minerAddress
            );
            MinerAPI.changeBeneficiary(
                minerAddress,
                MinerTypes.ChangeBeneficiaryParams({
                    new_beneficiary: minerInfo.owner,
                    new_quota: BigInt(hex"00", false),
                    new_expiration: 0
                })
            );
        }
    }

    // ------------------ function only for dev ------------------end
    //
    modifier onlyOwner() {
        require(msg.sender == _owner, "unauthorized");
        _;
    }

    function noStaking(bytes memory _addr) private view {
        require(minerStaking[_addr].quota == 0, "unstaking first");
    }

    function haveStaking(bytes memory _addr) private view {
        require(minerStaking[_addr].quota > 0, "staking first");
    }

    function checkExchangeRate(uint256 exchRate, uint256 slippage)
        private
        view
    {
        // require(
        //     (exchRate - slippage) <= _exchangeRate &&
        //         _exchangeRate <= (exchRate + slippage),
        //     "check exchange rate failed"
        // );
    }

    function checkInterestRate(uint256 interest_rate, uint256 slippage)
        private
        view
    {
        // require(
        //     (interest_rate - slippage) <= _interestRate &&
        //         _interestRate <= (interest_rate + slippage),
        //     "check interest rate failed"
        // );
    }

    function isBindMiner(address account, bytes memory minerAddr) private view {
        require(account != address(0), "invalid account");
        require(minerBindsMap[minerAddr] == account, "not bind");
    }
}
