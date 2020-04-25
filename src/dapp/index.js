import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

(async() => {
    let result = null;
    let contract = new Contract('localhost', () => {
        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        // User-submitted transaction
        DOM.elid('oracle-submit').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('insurance-buy').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let ticket = DOM.elid('ticket-number').value;
            let amount = DOM.elid('amount').value;
            // Write transaction
            contract.buyInsurance(flight, ticket, amount, (error, result) => {
                console.log('error', error);
                console.log('result', result);
                display(
                    'Insurance', 'Insurance purchase',
                    [
                        { label: 'Flight number', error: error, value: result.flight.name },
                        { label: 'Ticket Number',  value: result.ticket },
                        { label: 'Amount',  value: result.amount },
                    ]
                );

            });
        })

        // User-submitted transaction
        DOM.elid('insurance-withdraw').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.withdrawInsurance((error, result) => {
                display(
                    'Insurance', 'Insurance purchase',
                    [
                        { label: 'Report', error: error, value: result}
                    ]);
            });
        })
    });
})();

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value text-break'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.prepend(section);
}
