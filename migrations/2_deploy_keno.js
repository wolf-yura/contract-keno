const Keno = artifacts.require('Keno');

module.exports = async function (deployer) {

    await deployer.deploy(
        Keno,
        "0x5224C8942e318aAb995Ff50F07cf90ddd34EaDDf", // Deployed ULP Address
        "0x6db26bDE37C4201eCedB71d669e89e935Fea4ccF", // Deployed GBTS Address
        4, // Game Id
    );

    return;
};
