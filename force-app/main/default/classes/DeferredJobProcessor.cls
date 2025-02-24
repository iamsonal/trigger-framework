/**
 * Created by sonal on 2025-02-22.
 */

public with sharing class DeferredJobProcessor implements Schedulable {
    private static final Integer DEFAULT_MINIMUM_SCHEDULE_INTERVAL_MINUTES = 5;
    private static final String DEFAULT_DEFERRED_JOB_CRON_PREFIX = 'ProcessDeferredJobs_';

    @TestVisible
    private static Boolean isScheduleOverride = false;

    public void execute(SchedulableContext sc) {
        processDeferredJobs();
    }

    private static void processDeferredJobs() {
        Integer remainingQueueableSlots = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();

        if (remainingQueueableSlots <= 0) {
            scheduleNextExecution();
            return;
        }

        // Query pending deferred jobs
        List<DeferredQueueableJob__c> pendingJobs = [
            SELECT Id, HandlerName__c, Operation__c, SObjectName__c, ContextData__c, CreatedDate, Status__c
            FROM DeferredQueueableJob__c
            WHERE Status__c = 'Pending'
            ORDER BY CreatedDate ASC
            LIMIT :remainingQueueableSlots
        ];

        processJobs(pendingJobs);

        handleRemainingJobs();
    }

    private static void processJobs(List<DeferredQueueableJob__c> pendingJobs) {
        List<DeferredQueueableJob__c> jobsToUpdate = new List<DeferredQueueableJob__c>();

        for (DeferredQueueableJob__c job : pendingJobs) {
            if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
                break; // Exit the loop if queue is full
            }

            try {
                processJob(job);
                // Mark job as processed
                job.Status__c = 'Processed';
                job.LastProcessedDate__c = System.now();
                jobsToUpdate.add(job);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error processing deferred job ' + job.Id + ': ' + e.getMessage());
            }
        }

        if (!jobsToUpdate.isEmpty()) {
            update jobsToUpdate;
        }
    }

    private static void processJob(DeferredQueueableJob__c job) {
        // Initialize the handler
        ITriggerExecutable handler = TriggerDispatcher.initializeHandlerFromName(job.HandlerName__c);

        // Deserialize the context
        TriggerContext asyncContext = (TriggerContext) JSON.deserialize(job.ContextData__c, TriggerContext.class);

        System.enqueueJob(
            new TriggerDispatcher.AsynchronousFeatureExecution(
                handler,
                asyncContext,
                job.HandlerName__c,
                job.Operation__c,
                job.SObjectName__c
            )
        );
    }

    private static void handleRemainingJobs() {
        // Check if there are more pending jobs
        Integer remainingJobs = [SELECT COUNT() FROM DeferredQueueableJob__c WHERE Status__c = 'Pending'];

        if (remainingJobs > 0) {
            if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
                // Schedule next execution if queue is full
                scheduleNextExecution();
            } else {
                // Chain the job if queue isn't full
                System.enqueueJob(new DeferredJobQueueable());
            }
        } else {
            // Even if there are no pending jobs, ensure there's a scheduled job for future processing
            scheduleNextExecution();
        }
    }

    private static void scheduleNextExecution() {
        cleanupExistingScheduledJobs();

        Integer existingScheduledJobsCount = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :getDeferredJobCronPrefix() + '%' AND State = 'WAITING'
        ];

        if (existingScheduledJobsCount == 0 || isScheduleOverride) {
            try {
                String cronExp = getNextCronExpression(getMinimumScheduleIntervalMinutes());
                String jobName = getDeferredJobCronPrefix() + System.now().getTime();
                System.schedule(jobName, cronExp, new DeferredJobProcessor());
                System.debug(LoggingLevel.INFO, 'Scheduled new deferred job processor: ' + jobName);
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Unexpected error scheduling deferred job processor: ' + e.getMessage()
                );
                // Log error or notify administrators
            }
        }
    }

    private static void cleanupExistingScheduledJobs() {
        try {
            List<CronTrigger> existingJobs = [
                SELECT Id
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE :getDeferredJobCronPrefix() + '%' AND State = 'DELETED'
            ];

            for (CronTrigger job : existingJobs) {
                try {
                    System.abortJob(job.Id);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error cleaning up job ' + job.Id + ': ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in cleanupExistingScheduledJobs: ' + e.getMessage());
        }
    }

    public static String getNextCronExpression(Integer minutesFromNow) {
        Datetime nextRunTime = System.now().addMinutes(minutesFromNow);
        return String.format(
            '0 {0} {1} {2} {3} ? {4}',
            new List<String>{
                String.valueOf(nextRunTime.minute()),
                String.valueOf(nextRunTime.hour()),
                String.valueOf(nextRunTime.day()),
                String.valueOf(nextRunTime.month()),
                String.valueOf(nextRunTime.year())
            }
        );
    }

    public static String getDeferredJobCronPrefix() {
        TriggerSettings__c settings = TriggerSettings__c.getInstance();
        return String.isNotBlank(settings?.DeferredJobCronPrefix__c)
            ? settings.DeferredJobCronPrefix__c
            : DEFAULT_DEFERRED_JOB_CRON_PREFIX;
    }

    public static Integer getMinimumScheduleIntervalMinutes() {
        TriggerSettings__c settings = TriggerSettings__c.getInstance();
        Decimal intervalMinutes = settings?.MinimumScheduleIntervalMinutes__c;
        return intervalMinutes != null ? intervalMinutes.intValue() : DEFAULT_MINIMUM_SCHEDULE_INTERVAL_MINUTES;
    }

    private class DeferredJobQueueable implements Queueable {
        public void execute(QueueableContext context) {
            processDeferredJobs();
        }
    }
}
