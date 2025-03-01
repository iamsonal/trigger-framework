/**
 * Created by sonal on 2024-09-27.
 *
 * TriggerDispatcher implements a flexible framework for dispatching trigger functionality,
 * both synchronously and asynchronously. It uses custom metadata (TriggerFeature__mdt) to
 * control which triggers execute which handlers.
 */

public with sharing class TriggerDispatcher {
    @TestVisible
    private static Map<String, List<TriggerFeature__mdt>> mockControlsMap;
    @TestVisible
    private static Boolean forceQueueableDefer = false;

    // Lazy-loaded map for trigger controls
    private static Map<String, List<TriggerFeature__mdt>> featureControlsMap = new Map<String, List<TriggerFeature__mdt>>();
    private static Map<String, Boolean> disabledSObjectMap;

    /**
     * Main entry point. External triggers call this method passing their SObject type.
     */
    public static void run(Schema.SObjectType sObjectType) {
        String sObjectName = sObjectType.getDescribe().getName();

        if (getDisabledSObjectMap().containsKey(sObjectName)) {
            return;
        }

        List<TriggerFeature__mdt> controls = getFeatureControls(sObjectName);
        if (controls.isEmpty()) {
            return;
        }

        TriggerContext syncContext = createTriggerContext(false, sObjectName);
        List<DeferredQueueableJob__c> deferredJobs = new List<DeferredQueueableJob__c>();

        for (TriggerFeature__mdt control : controls) {
            if (isFeatureApplicable(control, syncContext)) {
                processHandler(control, syncContext, sObjectName, deferredJobs);
            }
        }

        if (!deferredJobs.isEmpty()) {
            try {
                insert deferredJobs;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Unexpected error handling deferred jobs: ' + e.getMessage());
                throw new TriggerDispatcherException('Unexpected error handling deferred jobs: ' + e.getMessage());
            }
        }

        if (syncContext.isAfter) {
            TriggerMetrics.flushMetrics();
        }
    }

    /**
     * Process the given control. If the custom metadata indicates asynchronous execution,
     * then in a before-trigger context an exception is raised. Otherwise, the handler is either
     * enqueued immediately (if queueable slots exist) or a deferred job record is created.
     */
    private static void processHandler(
        TriggerFeature__mdt control,
        TriggerContext syncContext,
        String sObjectName,
        List<DeferredQueueableJob__c> deferredJobs
    ) {
        try {
            ITriggerExecutable handler = initializeHandlerFromName(control.Handler__c);
            if (handler == null) {
                return;
            }

            String operation = syncContext.operation.name();

            if (control.Asynchronous__c) {
                if (syncContext.isBefore) {
                    throw new TriggerDispatcherException(
                        'Asynchronous execution is not allowed in before trigger context. Feature: ' +
                        control.DeveloperName
                    );
                }

                TriggerContext asyncContext = createTriggerContext(true, sObjectName);

                // Calculate remaining queueable slots
                Integer remainingQueueableSlots = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();

                if (remainingQueueableSlots > 0 && !forceQueueableDefer) {
                    // Enqueue the job immediately
                    System.enqueueJob(
                        new AsynchronousFeatureExecution(
                            handler,
                            asyncContext,
                            control.Handler__c,
                            operation,
                            sObjectName
                        )
                    );
                } else {
                    // Defer the job
                    DeferredQueueableJob__c deferredJob = createDeferredJob(
                        handler,
                        asyncContext,
                        control.Handler__c,
                        operation,
                        sObjectName
                    );
                    deferredJobs.add(deferredJob);
                }
            } else {
                // Synchronous execution
                String executionId = TriggerMetrics.startMetrics(
                    control.Handler__c,
                    operation,
                    sObjectName,
                    syncContext.size
                );
                handler.execute(syncContext);
                TriggerMetrics.endMetrics(control.Handler__c, operation, sObjectName, executionId);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in TriggerDispatcher: ' + e.getMessage());
            throw e;
        }
    }

    /**
     * Initializes a handler class by name. TThe resulting class must implement ITriggerExecutable and expose a no-argument constructor.
     */
    public static ITriggerExecutable initializeHandlerFromName(String handlerName) {
        if (String.isNotBlank(handlerName)) {
            try {
                Type handlerType = Type.forName(handlerName);
                if (handlerType != null) {
                    Object handlerInstance = handlerType.newInstance();
                    if (handlerInstance instanceof ITriggerExecutable) {
                        return (ITriggerExecutable) handlerInstance;
                    } else {
                        throw new TriggerDispatcherException(
                            'Handler class does not implement ITriggerExecutable: ' + handlerName
                        );
                    }
                } else {
                    throw new TriggerDispatcherException('Handler class not found: ' + handlerName);
                }
            } catch (Exception e) {
                throw new TriggerDispatcherException(
                    'Error initializing handler: ' + handlerName + '. ' + e.getMessage()
                );
            }
        }
        return null;
    }

    private static Boolean isFeatureApplicable(TriggerFeature__mdt control, TriggerContext context) {
        return control.IsActive__c &&
            isOperationEnabled(control, context.operation) &&
            !shouldBypassTrigger(control) &&
            hasRequiredPermission(control);
    }

    private static Boolean shouldBypassTrigger(TriggerFeature__mdt control) {
        if (String.isNotBlank(control.BypassPermission__c)) {
            return FeatureManagement.checkPermission(control.BypassPermission__c);
        }
        return false;
    }

    private static Boolean hasRequiredPermission(TriggerFeature__mdt control) {
        if (String.isNotBlank(control.RequiredPermission__c)) {
            return FeatureManagement.checkPermission(control.RequiredPermission__c);
        }
        return true; // If no required permission is specified, return true
    }

    private static TriggerContext createTriggerContext(Boolean isAsyncMode, String sObjectName) {
        return new TriggerContext(
            Trigger.operationType,
            Trigger.old,
            Trigger.new,
            Trigger.oldMap,
            Trigger.newMap,
            Trigger.isExecuting,
            Trigger.isInsert,
            Trigger.isUpdate,
            Trigger.isDelete,
            Trigger.isUndelete,
            Trigger.isBefore,
            Trigger.isAfter,
            Trigger.size,
            isAsyncMode,
            sObjectName
        );
    }

    @TestVisible
    private static Boolean isOperationEnabled(TriggerFeature__mdt control, TriggerOperation operation) {
        switch on operation {
            when BEFORE_INSERT {
                return control.BeforeInsert__c;
            }
            when AFTER_INSERT {
                return control.AfterInsert__c;
            }
            when BEFORE_UPDATE {
                return control.BeforeUpdate__c;
            }
            when AFTER_UPDATE {
                return control.AfterUpdate__c;
            }
            when BEFORE_DELETE {
                return control.BeforeDelete__c;
            }
            when AFTER_DELETE {
                return control.AfterDelete__c;
            }
            when AFTER_UNDELETE {
                return control.AfterUndelete__c;
            }
            when else {
                return false;
            }
        }
    }

    private static List<TriggerFeature__mdt> getFeatureControls(String sObjectName) {
        // First check if we have mock controls (for testing)
        if (Test.isRunningTest() && mockControlsMap != null && mockControlsMap.containsKey(sObjectName)) {
            return mockControlsMap.get(sObjectName);
        }

        if (!featureControlsMap.containsKey(sObjectName)) {
            List<TriggerFeature__mdt> features = [
                SELECT
                    DeveloperName,
                    Handler__c,
                    IsActive__c,
                    LoadOrder__c,
                    BeforeInsert__c,
                    AfterInsert__c,
                    BeforeUpdate__c,
                    AfterUpdate__c,
                    BeforeDelete__c,
                    AfterDelete__c,
                    AfterUndelete__c,
                    Asynchronous__c,
                    SObjectName__c,
                    BypassPermission__c,
                    RequiredPermission__c
                FROM TriggerFeature__mdt
                WHERE SObjectName__c = :sObjectName AND IsActive__c = TRUE
                ORDER BY LoadOrder__c ASC
            ];
            featureControlsMap.put(sObjectName, features);
        }

        return featureControlsMap.get(sObjectName);
    }

    private static Map<String, Boolean> getDisabledSObjectMap() {
        if (disabledSObjectMap == null) {
            disabledSObjectMap = new Map<String, Boolean>();
            for (SObjectTriggerControl__c control : SObjectTriggerControl__c.getAll().values()) {
                if (control.IsDisabled__c) {
                    disabledSObjectMap.put(control.SObjectName__c, true);
                }
            }
        }
        return disabledSObjectMap;
    }

    private static DeferredQueueableJob__c createDeferredJob(
        ITriggerExecutable handler,
        TriggerContext asyncContext,
        String handlerName,
        String operation,
        String sObjectName
    ) {
        return new DeferredQueueableJob__c(
            HandlerName__c = handlerName,
            ContextData__c = JSON.serialize(asyncContext),
            Status__c = 'Pending',
            Operation__c = operation,
            SObjectName__c = sObjectName
        );
    }

    @TestVisible
    private static void setMockControls(String sObjectName, List<TriggerFeature__mdt> mockControls) {
        if (mockControlsMap == null) {
            mockControlsMap = new Map<String, List<TriggerFeature__mdt>>();
        }
        mockControlsMap.put(sObjectName, mockControls);
    }

    public class AsynchronousFeatureExecution implements Queueable, Database.AllowsCallouts {
        private ITriggerExecutable handler;
        private TriggerContext context;
        private String handlerName;
        private String operation;
        private String sObjectName;

        public AsynchronousFeatureExecution(
            ITriggerExecutable handler,
            TriggerContext context,
            String handlerName,
            String operation,
            String sObjectName
        ) {
            this.handler = handler;
            this.context = context;
            this.handlerName = handlerName;
            this.operation = operation;
            this.sObjectName = sObjectName;
        }

        public void execute(System.QueueableContext qc) {
            String executionId = TriggerMetrics.startMetrics(handlerName, operation, sObjectName, context.size);
            this.handler.execute(this.context);
            TriggerMetrics.endMetrics(handlerName, operation, sObjectName, executionId);

            if (this.context.isAfter) {
                TriggerMetrics.flushMetrics();
            }
        }
    }

    public class TriggerDispatcherException extends Exception {
    }
}
