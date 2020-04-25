import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let oracleList = [];

web3.eth.getAccounts().then((accounts) => {
    accounts.slice(21,50).forEach((account) => {
        flightSuretyApp.methods.registerOracle().send({from: account, value: 12, gas: 6721975}).then(() => {
            flightSuretyApp.methods.getMyIndexes().call({from: account}).then((indexes) => {
                oracleList.push({
                    addr: account,
                    indexes: indexes
                });
            });
        });
    });
});

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
}, function (error, event) {
    if (error) console.log(error)
    let result = event.returnValues;
    let mockStatusCode = Math.floor(Math.random() * 6) * 10;
    console.log("Event triggered for flight " + result.airline + " - " + result.flight + " with index " + result.index);

    oracleList.forEach((oracle) => {
        oracle.indexes.forEach((index) => {
            flightSuretyApp.methods.submitOracleResponse(
                index,
                result.airline,
                result.flight,
                result.timestamp,
                mockStatusCode
            ).send(
                { from: oracle.address, gas:6721975}
            ).then(res => {
                console.log(res);
            }).catch(e => {
                console.log(e);
            });
        });
    });
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
})

export default app;