import { LightningElement, track } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';

export default class QdxLogMonitor extends LightningElement {
    filterOptions = [{label: 'All', value: 'All'}];
    selectedUser = 'All';
    displayFilterOptions = false;
    gridData = [];
    gridColumns = [
        {
            type: 'text',
            fieldName: 'QDX_Context__c', //, QDX_User__c, , , , 
            label: 'Context',
            initialWidth: 150
        },
        {
            type: 'text',
            fieldName: 'QDX_UserName__c',
            label: 'User',
            initialWidth: 200
        },
        {
            type: 'text',
            fieldName: 'QDX_Class__c',
            label: 'Class',
            initialWidth: 150
        },
        {
            type: 'text',
            fieldName: 'QDX_Method__c',
            label: 'Method',
            initialWidth: 150
        },
        {
            type: 'number',
            fieldName: 'QDX_Line__c',
            label: 'Line',
            initialWidth: 50
        },
        {
            type: 'text',
            fieldName: 'QDX_Message__c',
            label: 'Message'
        }
    ]

    // Initializes the component
    connectedCallback() {       
        // Register error listener       
        this.registerErrorListener(); 
        this.handleSubscribe();     
    }

    // Handles subscribe button click
    handleSubscribe() {
        // Callback invoked whenever a new event message is received
        const messageCallback = function(response) {
            const log = response.data.payload;
            this.updateFilterOptions(log);
            console.log('New message received: ', JSON.stringify(log, null, 4));
            console.log('Number of records: ' + this.gridData.length);
            console.log(this.selectedUser + ' != ' + log.QDX_User__c);
            if (this.selectedUser != 'All' && this.selectedUser != log.QDX_User__c) return;

            const context = log.QDX_Context__c;

            let foundParent = false;
            for (const record of this.gridData) {
                if (record.QDX_Context__c === context) {
                    record._children.push(log);
                    foundParent = true;
                    break;
                }
            }
            if (!foundParent) {
                this.gridData.push({QDX_Context__c: context, _children: [log]});
            }
            
            this.gridData = [...this.gridData];
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe('/event/QDX_Log__e', -1, messageCallback.bind(this)).then(response => {
            // Response contains the subscription information on subscribe call
            console.log('Subscription request sent to: ', JSON.stringify(response.channel));
        });
    }

    updateFilterOptions(log) {
        if (this.filterOptions.find(option => option.value == log.QDX_User__c) === undefined) {
            this.filterOptions.push({label: log.QDX_UserName__c, value: log.QDX_User__c});
        }
        if (this.filterOptions.length > 2 && !this.displayFilterOptions) this.displayFilterOptions = true;
        this.filterOptions = [...this.filterOptions];
    }

    handleFilterChange(event) {
        for (let i = 0; i < this.gridData.length; i++) {
            if(event.target.value != this.gridData[i].QDX_User__c) this.gridData.splice(i, 1);
        }
        this.selectedUser = event.target.value;
        this.gridData = [...this.gridData];
    }

    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            // Error contains the server-side error
        });
    }
}