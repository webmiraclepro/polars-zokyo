const { accounts, contract } = require('@openzeppelin/test-environment');

const {
    BN,
    ether,
    time,
} = require('@openzeppelin/test-helpers');
const { duration } = require('@openzeppelin/test-helpers/src/time');

require('chai').should();

const Reservoir = contract.fromArtifact('Reservoir');
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const FarmingPool = contract.fromArtifact('FarmingPool');

describe('Contract farming/FarmingPool.sol', function () {
    const [
        deployer,
        user
    ] = accounts;

    const TOKEN_NAME = 'TEST';
    const TOKEN_SYMBOL = 'TEST';
    const INITIAL_SUPPLY = ether('500000000');
    const DEFAULT_TOKENS_PER_SECOND = ether('1');

    beforeEach(async function () {
        this.tokenRewards = await ERC20Mock.new(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            deployer,
            INITIAL_SUPPLY
        );

        this.tokenLp1 = await ERC20Mock.new(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            user,
            INITIAL_SUPPLY
        );

        this.tokenLp2 = await ERC20Mock.new(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            user,
            INITIAL_SUPPLY
        );

        this.farmingPool = await FarmingPool.new(
            this.tokenRewards.address,
            DEFAULT_TOKENS_PER_SECOND,
            (await time.latest()),
            [ether("0.6"), ether("0.4")],
            [this.tokenLp1.address, this.tokenLp2.address],
            { from: deployer });

        this.reservoir = await Reservoir.new(
            this.tokenRewards.address,
            this.farmingPool.address
        );

        await this.tokenRewards.transfer(
            this.reservoir.address,
            INITIAL_SUPPLY,
            { from: deployer });

        await this.farmingPool.initializeTokenReservoir(
            this.reservoir.address,
            { from: deployer });
    });

    it('should set correct pool length', async function () {
        (await this.farmingPool.poolLength()).should.be.bignumber.equal(new BN(2));
    });

    it('should allow emergency withdraw', async function () {
        await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })

        await this.farmingPool.deposit(
            new BN(0),
            ether('500000000'),
            { from: user });

        (await this.tokenLp1.balanceOf(user))
            .should.be.bignumber.equal(ether('0'));

        await time.increase(duration.minutes(1)); // 1 min

        await this.farmingPool.emergencyWithdraw(
            new BN(0),
            { from: user });

        (await this.tokenLp1.balanceOf(user))
            .should.be.bignumber.equal(ether('500000000'));
    });

    it('should be equal pendingTokens and claimed tokens', async function () {
        await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })

        await this.farmingPool.deposit(
            new BN(0),
            ether('500000000'),
            { from: user });

        (await this.tokenLp1.balanceOf(user))
            .should.be.bignumber.equal(ether('0'));

        await time.increase(duration.minutes(1)); // 1 min

        let pendingTokens = await this.farmingPool.pendingTokens(new BN(0), user);

        await this.farmingPool.withdraw(
            new BN(0),
            ether('500000000'),
            { from: user });

        (await this.tokenLp1.balanceOf(user))
            .should.be.bignumber.equal(ether('500000000'));

        (await this.tokenRewards.balanceOf(user))
            .should.be.bignumber.equal(pendingTokens);
    });

    describe('deposit/withdraw lp and rewards', function () {
        it('should be correct for first pool', async function () {
            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.minutes(1)); // 1 min
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 12 * 60 * 60% * 1/2 = 216 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('216'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('220'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('212'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('216')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('212')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('220')));
        });
    
        it('should be correct for second pool', async function () {
            await this.tokenLp2.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(1),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp2.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.minutes(1)); // 1 min
    
            await this.farmingPool.withdraw(
                new BN(1),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp2.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 12 * 60 * 40% * 1/2 = 144 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('144'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('148'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('140'));

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('144')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('140')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('148')));
        });
    
        it('should be correct for both pools', async function () {
            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
            await this.tokenLp2.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
            await this.farmingPool.deposit(
                new BN(1),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
            (await this.tokenLp2.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.minutes(1)); // 1 min
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
            await this.farmingPool.withdraw(
                new BN(1),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
            (await this.tokenLp2.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 12 * 60 = 720 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('720'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('733'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('707'));

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('720')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('707')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('733')));
        });
    });

    describe('deposit/withdraw lp and rewards: n weeks after the start', function () {
        it('should be correct after 1 week', async function () {
            await time.increase(duration.weeks(1)); // 1 week after start

            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.minutes(1)); // 1 min
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 11 * 60 * 60% * 1/2 = 198 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('198'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('202'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('194'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('198')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('194')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('202')));
        });

        it('should be correct after 2 weeks', async function () {
            await time.increase(duration.weeks(2)); // 2 weeks after start

            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.minutes(1)); // 1 min
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 10 * 60 * 60% * 1/2 = 180 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('180'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('184'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('176'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('180')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('176')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('184')));
        });

        it('should be correct after 12 weeks', async function () {
            await time.increase(duration.weeks(12)); // 12 weeks after start

            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.minutes(1)); // 1 min
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 1 * 60 * 60% * 1/2 = 18 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('18'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('19.1'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('16.9'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('18')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('16.9')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('19.1')));
        });
    });

    describe('deposit/withdraw lp and rewards: from start', function () {
        it('should be correct for 2 weeks duration', async function () {
            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.weeks(2)); // 2 weeks after start
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * (12 + 11) * 7 * 86400 * 60% * 1/2 = 4,173,120 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('4173120'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('4173131'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('4173109'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('4173120')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('4173109')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('4173131')));
        });

        it('should be correct for 24 weeks duration', async function () {
            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.weeks(24)); // 24 weeks after start
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * (12 + 11 + ... + 1 + 12 * 1) * 7 * 86400 * 60% * 1/2 = 16,329,600 tokens

            // small fluctuations due to testing timestamps and rounding
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('16329800'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('16329500'));
    
            // small fluctuations due to testing timestamps and rounding
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('16329500')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('16329800')));
        });
    });

    describe('deposit/withdraw lp and rewards: from 24 weeks after the start', function () {
        beforeEach(async function () {
            await time.increase(duration.weeks(24)); // 24 weeks after start
        });

        it('should be correct for 2 weeks duration', async function () {
            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.weeks(2)); // 2 weeks
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 2 * 1 * 7 * 86400 * 60% * 1/2 = 362,880 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('362880'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('362900'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('362850'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('362880')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('362850')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('362900')));
        });

        it('should be correct for 24 weeks duration', async function () {
            await this.tokenLp1.approve(this.farmingPool.address, ether('500000000'), { from: user })
    
            await this.farmingPool.deposit(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('0'));
    
            await time.increase(duration.weeks(24)); // 24 weeks after start
    
            await this.farmingPool.withdraw(
                new BN(0),
                ether('500000000'),
                { from: user });
    
            (await this.tokenLp1.balanceOf(user))
                .should.be.bignumber.equal(ether('500000000'));
    
            // 1 * 24 * 1 * 7 * 86400 * 60% * 1/2 = 4,354,560 tokens

            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(user))
            //     .should.be.bignumber.equal(ether('4354560'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.lessThan(ether('4354600'));
            (await this.tokenRewards.balanceOf(user))
                .should.be.bignumber.greaterThan(ether('4354500'));
    
            // small fluctuations due to testing timestamps
            // (await this.tokenRewards.balanceOf(this.reservoir.address))
            //     .should.be.bignumber.equal(INITIAL_SUPPLY.sub(ether('4354560')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.lessThan(INITIAL_SUPPLY.sub(ether('4354500')));
            (await this.tokenRewards.balanceOf(this.reservoir.address))
                .should.be.bignumber.greaterThan(INITIAL_SUPPLY.sub(ether('4354600')));
        });
    });
});
