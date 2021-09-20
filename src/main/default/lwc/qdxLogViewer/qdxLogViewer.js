import { LightningElement, track } from 'lwc';

export default class QdxLogViewer extends LightningElement {
    userNameFilter = [{label: 'All', value: 'All'}];
    classNameFilter = [{label: 'All', value: 'All'}];
    selectedUser = 'All';
    selectedClass = 'All';
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

    handleLogText(event) {
        if (!event.target.value) return;
        try {
            this.gridData = JSON.parse(event.target.value);
        } catch(e) {
            console.log('Invalid JSON');
        }
    }
}