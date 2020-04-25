import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {
        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.owner = null;
        this.airline = null;
        this.flights = [];
        this.passenger = null;
        this.initialize(callback);
    }

    async initialize(callback) {
        let self = this;
        let accounts = await this.web3.eth.getAccounts();
        self.owner = accounts[0];
        self.airline = accounts[1];
        self.passenger = accounts[11];
        const mockFlightList = ['EK573', 'EK053', 'QR60', 'QR546'];
        const mockTickets = [['112', '113'], ['121', '122'], ['445', '443'], ['556', '567']];

        let funded = await this.flightSuretyApp.methods.isFunded(self.airline).call();

        if (!funded) {
            await this.flightSuretyApp.methods
                .fundAirline()
                .send({
                    from: self.airline,
                    value: self.web3.utils.toWei('10', "ether"),
                    gas: 6721975
                });
        }

        for (let i = 0; i < mockFlightList.length; i++) {
            let departure = Math.floor(new Date(2020, 8, 18, 10, 30, 0, 0) / 1000)
            let _flight = {
                name: mockFlightList[i],
                airline: this.airline,
                departure: departure,
                tickets: mockTickets[i]
            };
            await this.flightSuretyApp.methods.registerFlight(
                _flight.name,
                _flight.departure,
                _flight.tickets
            )
            .send({from: this.airline, gas: 6721975});

            mockFlightList[mockFlightList[i]] = _flight;

            console.log("Registered Flight - " + _flight.name);
            console.log("Flight details - " + JSON.stringify(_flight));
        }

        // while(this.flights.length < 5) {
        //     this.flights.push(accts[counter++]);
        // }
        //
        // while(this.passengers.length < 5) {
        //     this.passengers.push(accts[counter++]);
        // }

        callback();
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airline,
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
        });
    }

    buyInsurance(flight, ticket, amount, callback) {
        let self = this;
        let payload = {
            flight: flight,
            ticket: ticket,
            amount: amount
        }
        self.flightSuretyApp.methods
            .buyInsurance(payload.flight, payload.ticket)
            .send({
                from: self.passenger,
                value: self.web3.utils.toWei(payload.amount, "ether"),
                gas: 6721975
            }, (error, result) => {
                console.log(error);
                console.log(result);
                callback(error, payload);
        });
    }

    withdrawInsurance(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .receivePayout()
            .send({
                from: self.passenger,
            }, (error, result) => {
                callback(error, result);
        });
    }
}