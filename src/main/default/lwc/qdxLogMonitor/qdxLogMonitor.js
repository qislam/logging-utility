import { LightningElement, track } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';

export default class QdxLogMonitor extends LightningElement {
    filterOptions = [{label: 'All', value: 'All'}];
    @track userNameFilter = [{label: 'All', value: 'All'}];
    @track classNameFilter = [{label: 'All', value: 'All'}];
    selectedUser = 'All';
    selectedClass = 'All';
    displayUserFilter = false;
    displayClassFilter = false;
    displayFilterOptions = false;
    gridData = [];
    gridColumns = [
        {
            type: 'text',
            fieldName: 'QDX_Context__c',
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
        // Storing in session to avoid clearing events if moving to a different tab within salesforce app.
        // Events data will be still be cleared on browser refresh.
        if (sessionStorage.qdxLogData) this.gridData = [...JSON.parse(sessionStorage.qdxLogData)];
    }

    disconnectedCallback() {
        //sessionStorage.qdxLogData = JSON.stringify(this.gridData);
    }

    // Handles subscribe button click
    handleSubscribe() {
        // Callback invoked whenever a new event message is received
        const messageCallback = function(response) {
            const log = response.data.payload;
            this.storeDataInSession(log);
            this.updateFilterOptions(log);

            if (this.selectedUser != 'All' && this.selectedUser != log.QDX_User__c) return;
            if (this.selectedClass != 'All' && this.selectedClass != log.QDX_Class__c) return;

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
        if (this.userNameFilter.find(option => option.value == log.QDX_User__c) === undefined) {
            this.userNameFilter.push({label: log.QDX_UserName__c, value: log.QDX_User__c});
        }
        if (this.classNameFilter.find(option => option.value == log.QDX_Class__c) === undefined) {
            this.classNameFilter.push({label: log.QDX_Class__c, value: log.QDX_Class__c});
        }
        
        this.userNameFilter = [...this.userNameFilter];
        this.classNameFilter = [...this.classNameFilter];
        this.displayUserFilter = this.userNameFilter.length > 2;
        this.displayClassFilter = this.classNameFilter.length > 2;
    }

    storeDataInSession(log) {
        let tempData = [];
        if (sessionStorage.qdxLogData) tempData = [...JSON.parse(sessionStorage.qdxLogData)];

        let context = log.QDX_Context__c;
        let foundParent = false;
        for (const record of tempData) {
            if (record.QDX_Context__c === context) {
                record._children.push(log);
                foundParent = true;
                break;
            }
        }
        if (!foundParent) {
            tempData.push({QDX_Context__c: context, _children: [log]});
        }
        sessionStorage.qdxLogData = JSON.stringify(tempData);
    }

    handleFilterChange(event) {
        let tempData = [];
        for (const contextGroup of [...JSON.parse(sessionStorage.qdxLogData)]) {
            for (const log of contextGroup._children) {
                if ( 
                    (this.selectedUser == 'All' && this.selectedClass == 'All')
                    || (this.selectedClass == 'All' && this.selectedUser != 'All' 
                        && this.selectedUser == log.QDX_User__c) 
                    || (this.selectedUser == 'All' && this.selectedClass != 'All' 
                        && this.selectedClass == log.QDX_Class__c)
                    || (this.selectedClass != 'All' && this.selectedUser != 'All' 
                        && this.selectedUser == log.QDX_User__c 
                        && this.selectedClass == log.QDX_Class__c)
                ) {
                    let context = log.QDX_Context__c;
                    let foundParent = false;
                    for (const record of tempData) {
                        if (record.QDX_Context__c === context) {
                            record._children.push(log);
                            foundParent = true;
                            break;
                        }
                    }
                    if (!foundParent) {
                        tempData.push({QDX_Context__c: context, _children: [log]});
                    }
                }
            }
        }

        this.gridData = [...tempData];
    }

    handleUserFilterChange(event) {
        this.selectedUser = event.target.value;
        this.handleFilterChange();
    }

    handleClassFilterChange(event) {
        this.selectedClass = event.target.value;
        this.handleFilterChange();
    }

    handleDownload(event){
        let dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(this.gridData));
        let downloadAnchorNode = document.createElement('a');
        downloadAnchorNode.setAttribute("href",     dataStr);
        downloadAnchorNode.setAttribute("download", "QDX_Logs_" + Date.now() + ".json");
        document.body.appendChild(downloadAnchorNode); // required for firefox
        downloadAnchorNode.click();
        downloadAnchorNode.remove();
      }

    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            // Error contains the server-side error
        });
    }
}