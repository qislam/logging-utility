# Salesforce Logging Utility

This utility is based on salesforce platform events for providing an efficient alternative to logging by using System.debug method.

## How to use/configure

Once installed, you can start using it by setting up "Log Setting" custom metadata type records. Set the MasterLabel of record to same as the class API name. This is case sensitive so make sure it matches exactly with the class API name.

Start using it by replacing any System.debug with QDX_Log.debug method. If you need to persist error in database, you can call the QDX_Log.error method. For this to work, you will also need to configure a metadata type record where QDX_ErrorClassName is set to the class API name where QDX_Log.IError interface is implemented.
