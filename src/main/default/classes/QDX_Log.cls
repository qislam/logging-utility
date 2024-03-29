/*
* QDX_Log
* @author Qamar Islam (https://github.com/qislam)
* @description This class is for replacing need to place QDX_Log.debug statements.
* To create persistent error log records implement the QDX_Log.IError interface and create a 
* metadata type record with the name of that class.
* @credit This is inspired by https://github.com/rsoesemann/apex-unified-logging
*/
public with sharing class QDX_Log {
	private static final String ORG_NAMESPACE = null; //[SELECT NamespacePrefix FROM Organization].NamespacePrefix;
    private static final String CLASSNAME = QDX_Log.class.getName();
	private static final Pattern STACK_LINE = Pattern.compile('^(?:Class\\.)?([^.]+)\\.?([^\\.\\:]+)?[\\.\\:]?([^\\.\\:]*): line (\\d+), column (\\d+)$');
	private static final String THIS_CONTEXT = timestamp();
    private static List<QDX_Log__e> eventsToPublish;

    @TestVisible
    private static Boolean setupClassConfig = true;

	// PUBLIC
	public static void debug(String message) {
		debug(message, new List<Object>(), getContextId());
	}

	public static void debug(String message, List<Object> values) {
		debug(message, values, getContextId());
	}

	public static void debug(String message, String contextId) {
		debug(message, new List<Object>(), contextId);
	}

    public static void debug(Object obj) {
        debug('' + obj, new List<Object>(), getContextId());
    }

    public static void debug(Object obj, String contextId) {
        debug('' + obj, new List<Object>(), contextId);
    }

    public static void debug(Object[] objList) {
        debug('' + objList, new List<Object>(), getContextId());
    }

    public static void debug(Object[] objList, String contextId) {
        debug('' + objList, new List<Object>(), contextId);
    }

	public static void debug(String message, List<Object> values, String contextId) {
		emit(message, values, contextId, LoggingLevel.DEBUG);
	}

	public static void error(String message) {
		error(message, new List<Object>(), getContextId());
	}

	public static void error(String message, List<Object> values) {
		error(message, values, getContextId());
	}

	public static void error(String message, String contextId) {
		error(message, new List<Object>(), contextId);
	}

    public static void error(Exception ex) {
        error(
            '{1}:{0}\n{2}',
            new List<Object>{ex.getMessage(), ex.getTypeName(), ex.getStackTraceString()},
            getContextId()
        );
    }

    public static void error(Object obj) {
        error('' + obj, new List<Object>(), getContextId());
    }

    public static void error(Object obj, String contextId) {
        error('' + obj, new List<Object>(), contextId);
    }

    public static void error(Object[] objList) {
        error('' + objList, new List<Object>(), getContextId());
    }

    public static void error(Object[] objList, String contextId) {
        error('' + objList, new List<Object>(), contextId);
    }

	public static void error(String message, List<Object> values, String contextId) {
		emit(message, values, contextId, LoggingLevel.ERROR);
	}

    public static void limits() {
        emitLimits(null);
    }

    public static void limits(String contextId) {
        emitLimits(contextId);
    }

    public static void publish() {
        if (eventsToPublish == null) { eventsToPublish = new List<QDX_Log__e>(); }

        QDX_Log__e[] errorEvents = new List<QDX_Log__e>();

        for (QDX_Log__e event : eventsToPublish) {
            if (event.QDX_Level__c == LoggingLevel.ERROR.name()) { errorEvents.add(event); }
        }

        if (!eventsToPublish.isEmpty()) { EventBus.publish(eventsToPublish); }
        eventsToPublish.clear();

        if (!errorEvents.isEmpty()) { createError(errorEvents); }
    }

    public interface IError {
        void create(QDX_Log__e[] errorEvents);
    }

    // PRIVATE
    private static String getContextId() {
        return Request.getCurrent().getRequestId();
    }
    private static void emitLimits(String contextId) {
        String message = '';
        message += String.format(
            '{0} SOQL statements out of {1}.\n', 
            new List<Object>{Limits.getQueries(), Limits.getLimitQueries()}
        );
        message += String.format(
            '{0} SOQL rows out of {1}.\n', 
            new List<Object>{Limits.getQueryRows(), Limits.getLimitQueryRows()}
        );
        message += String.format(
            '{0} DML statements out of {1}.\n', 
            new List<Object>{Limits.getDmlStatements(), Limits.getLimitDmlStatements()}
        );
        message += String.format(
            '{0} DML rows out of {1}.\n', 
            new List<Object>{Limits.getDmlRows(), Limits.getLimitDmlRows()}
        );
        message += String.format(
            '{0} Publish Immediately DML statements out of {1}.\n', 
            new List<Object>{Limits.getPublishImmediateDML(), Limits.getLimitPublishImmediateDML()}
        );
        message += String.format(
            '{0}ms CPU time out of {1}ms.\n', 
            new List<Object>{Limits.getCpuTime(), Limits.getLimitCpuTime()}
        );
        message += String.format(
            '{0} bytes Heap size out of {1} bytes.\n', 
            new List<Object>{Limits.getHeapSize(), Limits.getLimitHeapSize()}
        );

        emit(message, new List<Object>(), contextId, LoggingLevel.DEBUG);
    }

    @TestVisible
	private static void emit(String message, List<Object> values, String contextId, LoggingLevel level) {
        QDX_LogSetting__mdt classConfig;

		if (!values.isEmpty()) { message = String.format(message, cast(values)); }
        Boolean AGGREGATE_EVENTS = true;
        
        currentEvent = new QDX_Log__e();
        currentEvent.QDX_User__c = UserInfo.getUserId();
        currentEvent.QDX_UserName__c = UserInfo.getUserName();
        currentEvent.QDX_Message__c = message;
        currentEvent.QDX_Level__c = level.name();
        currentEvent.QDX_Context__c = (contextId == null) ? THIS_CONTEXT : ''+ contextId;

        populateLocation(currentEvent);

        // MasterLabel must be same as the class name.
        List<QDX_LogSetting__mdt> classConfigList = [
            SELECT MasterLabel
            , DeveloperName
            , QDX_LogDate__c
            , QDX_Aggregate__c
            , QDX_Method__c
            FROM QDX_LogSetting__mdt
            WHERE DeveloperName = :currentEvent.QDX_Class__c
            AND MasterLabel = :currentEvent.QDX_Class__c
            AND QDX_LogDate__c != null
        ];
        if(!classConfigList.isEmpty()) { classConfig = classConfigList[0]; }

        if (Test.isRunningTest() && setupClassConfig) {
            classConfig = new QDX_LogSetting__mdt();
            classConfig.MasterLabel = 'QDX_Log_Test';
            classConfig.QDX_ErrorClassName__c = 'QDX_Log_Test';
            classConfig.QDX_LogDate__c = System.today();
            classConfig.QDX_Aggregate__c = true;
        }

        if (
            classConfig == null ||
            classConfig.QDX_LogDate__c < System.today() ||
            (classConfig.QDX_Method__c != null && classConfig.QDX_Method__c != currentEvent.QDX_Method__c) ||
            Limits.getPublishImmediateDML() > Limits.getLimitPublishImmediateDML() - 1
        ) {
            String debugFormat = 'QDX_LOG_MESSAGE From {0}.{1}() at line {2}: {3}';
            Object[] messageParams = new Object[]{
                currentEvent.QDX_Class__c,
                currentEvent.QDX_Method__c,
                currentEvent.QDX_Line__c,
                currentEvent.QDX_Message__c
            };
            System.debug(String.format(debugFormat, messageParams));
            if (currentEvent.QDX_Level__c == LoggingLevel.ERROR.name()) {
                createError(new List<QDX_Log__e>{currentEvent});
            }
            return;
        }
        if (!classConfig.QDX_Aggregate__c) {
            EventBus.publish(currentEvent);
            return;
        } 
        
        if (eventsToPublish == null) { eventsToPublish = new List<QDX_Log__e>(); }
        
        eventsToPublish.add(currentEvent);
	}

    @TestVisible
    private static void createError(QDX_Log__e[] errorEvents) {
        if (Limits.getDmlStatements() > Limits.getLimitDmlStatements() - 1) { return; }
        
        List<QDX_LogSetting__mdt> errorClassSettings = [
            SELECT QDX_ErrorClassName__c 
            FROM QDX_LogSetting__mdt
            WHERE QDX_ErrorClassName__c != null
            LIMIT 1
        ];

        if (Test.isRunningTest()) {
            errorClassSettings = new List<QDX_LogSetting__mdt>();
            QDX_LogSetting__mdt setting = new QDX_LogSetting__mdt();
            setting.MasterLabel = 'TestSettingForError';
            setting.QDX_ErrorClassName__c = 'QDX_Log_Test';
            errorClassSettings.add(setting);
        }

        if (errorClassSettings.isEmpty()) { return; }

        String errorClassName = errorClassSettings[0].QDX_ErrorClassName__c;

        Type t = Type.forName(errorClassName);
        if (t == null) { return; }
        
        try {
            IError errorClass = (IError)t.newInstance(); 
            errorClass.create(errorEvents);
        } catch(Exception e) {
            QDX_Log.debug(e.getMessage());
        }
    }

	private static List<String> cast(List<Object> values) {
		List<String> result = new List<String>();

		for(Object value : values) {
			result.add('' + value);
		}

		return result;
	}

	private static String timestamp() {
		return System.now().formatGmt('HH:mm:ss.SSS');
	}

	private static void populateLocation(QDX_Log__e logEvent) {
		// Note: Idea taken from https://salesforce.stackexchange.com/questions/153835
		List<String> stacktrace = new DmlException().getStackTraceString().split('\n');

		for(String line : stacktrace) {
			Matcher matcher = STACK_LINE.matcher(line);

			if(matcher.find() && !line.startsWith('Class.' + CLASSNAME + '.')) {
				Boolean hasNamespace = String.isNotBlank(matcher.group(3));

				if(hasNamespace) {
					logEvent.QDX_Class__c = (matcher.group(1).equals(ORG_NAMESPACE)) ? matcher.group(2) : matcher.group(1) + '.' + matcher.group(2);
					logEvent.QDX_Method__c = prettyMethod(matcher.group(3));
				}
				else {
					logEvent.QDX_Class__c = matcher.group(1);
					logEvent.QDX_Method__c = prettyMethod(matcher.group(2));
				}

				logEvent.QDX_Line__c = Integer.valueOf(matcher.group(4));

				return;
			}
		}
	}

	private static String prettyMethod(String method) {
		String result = (method == null) ? 'anonymous' : method;
		return (result.contains('init')) ? 'ctor' : result;
	}

    @TestVisible
	private static QDX_Log__e currentEvent = null;
}