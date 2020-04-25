const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {
    let firstAirline = '0x00b8FB19C75a0cF4cF57977eD05200f81Fa70b1c';

    deployer.deploy(FlightSuretyData, firstAirline)
        .then(() => {
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(() => {
                    let config = {
                        localhost: {
                            url: 'http://localhost:7545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }
                    if (fs.existsSync(__dirname + '/../src/dapp/config.json')) {
                        fs.unlinkSync(__dirname + '/../src/dapp/config.json');
                    }

                    if (fs.existsSync(__dirname + '/../src/server/config.json')) {
                        fs.unlinkSync(__dirname + '/../src/server/config.json');
                    }
                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                });
        });
}