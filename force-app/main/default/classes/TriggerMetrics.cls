/**
 * Created by sonal on 2025-02-14.
 */

public class TriggerMetrics {
    @TestVisible
    private static Boolean isMetricsEnabled = null;

    private static String transactionId = null;
    private static Integer executionSequence = 0;
    private static List<String> globalExecutionStack = new List<String>();

    private static Map<String, MetricSnapshot> activeSnapshots = new Map<String, MetricSnapshot>();
    private static List<TriggerMetric__c> metricsBuffer = new List<TriggerMetric__c>();

    private class MetricSnapshot {
        Long startTime;
        Integer cpuStart;
        Integer dmlStart;
        Integer queryStart;
        Integer recordCount;
        String executionId;
        String parentExecutionId;
        Integer depth;
        Integer sequence;
    }

    public static Boolean isMetricsEnabled() {
        if (isMetricsEnabled == null) {
            TriggerSettings__c settings = TriggerSettings__c.getInstance();
            isMetricsEnabled = settings?.IsMetricsEnabled__c == true;
        }
        return isMetricsEnabled;
    }

    private static void initializeTransactionIfNeeded() {
        if (transactionId == null) {
            transactionId =
                String.valueOf(System.now().getTime()) +
                '-' +
                String.valueOf(Math.random()).substring(2, 8);
            executionSequence = 0;
            globalExecutionStack.clear();
            System.debug(LoggingLevel.FINE, 'TriggerMetrics: Initialized new transaction: ' + transactionId);
        }
    }

    public static String startMetrics(String handler, String operation, String sObjectType, Integer count) {
        if (!isMetricsEnabled()) {
            return null;
        }

        initializeTransactionIfNeeded();

        // Increment sequence counter
        executionSequence++;

        // Generate unique execution ID
        String executionId = transactionId + '-' + String.valueOf(executionSequence);

        // Track parent-child relationship
        String parentExecutionId = null;
        if (!globalExecutionStack.isEmpty()) {
            parentExecutionId = globalExecutionStack[globalExecutionStack.size() - 1];
        }

        // Push current execution onto stack
        globalExecutionStack.add(executionId);

        System.debug(
            LoggingLevel.FINE,
            'TriggerMetrics: Starting metrics for ' +
                handler +
                ', Operation: ' +
                operation +
                ', SObject: ' +
                sObjectType +
                ', ExecutionId: ' +
                executionId +
                ', ParentId: ' +
                parentExecutionId +
                ', Depth: ' +
                globalExecutionStack.size()
        );

        MetricSnapshot snapshot = new MetricSnapshot();
        snapshot.startTime = System.now().getTime();
        snapshot.cpuStart = Limits.getCpuTime();
        snapshot.dmlStart = Limits.getDmlRows();
        snapshot.queryStart = Limits.getQueryRows();
        snapshot.recordCount = count;
        snapshot.executionId = executionId;
        snapshot.parentExecutionId = parentExecutionId;
        snapshot.depth = globalExecutionStack.size();
        snapshot.sequence = executionSequence;

        String key = generateMetricKey(handler, operation, sObjectType, executionId);
        activeSnapshots.put(key, snapshot);

        return executionId;
    }

    public static void endMetrics(String handler, String operation, String sObjectType, String executionId) {
        if (!isMetricsEnabled()) {
            return;
        }

        String key = generateMetricKey(handler, operation, sObjectType, executionId);
        MetricSnapshot snapshot = activeSnapshots.remove(key);
        if (snapshot == null) {
            System.debug(LoggingLevel.ERROR, 'TriggerMetrics: No active snapshot found for key: ' + key);
            return;
        }

        Integer indexToRemove = -1;
        for (Integer i = globalExecutionStack.size() - 1; i >= 0; i--) {
            if (globalExecutionStack[i] == executionId) {
                indexToRemove = i;
                break;
            }
        }

        if (indexToRemove != -1) {
            globalExecutionStack.remove(indexToRemove);
            System.debug(
                LoggingLevel.FINE,
                'TriggerMetrics: Removed execution ' +
                    executionId +
                    ' from stack. Current stack size: ' +
                    globalExecutionStack.size()
            );
        } else {
            System.debug(
                LoggingLevel.ERROR,
                'TriggerMetrics: Could not find ' + executionId + ' in execution stack to remove it.'
            );
        }

        Long endTime = System.now().getTime();
        metricsBuffer.add(
            new TriggerMetric__c(
                Handler__c = handler,
                Operation__c = operation,
                SObjectType__c = sObjectType,
                RecordCount__c = snapshot.recordCount,
                StartTime__c = Datetime.newInstance(snapshot.startTime),
                EndTime__c = Datetime.newInstance(endTime),
                ExecutionTime__c = endTime - snapshot.startTime,
                CPUTime__c = Limits.getCpuTime() - snapshot.cpuStart,
                DMLRows__c = Limits.getDmlRows() - snapshot.dmlStart,
                QueryRows__c = Limits.getQueryRows() - snapshot.queryStart,
                TransactionId__c = transactionId,
                ExecutionId__c = snapshot.executionId,
                ParentExecutionId__c = snapshot.parentExecutionId,
                Depth__c = snapshot.depth,
                Sequence__c = snapshot.sequence
            )
        );

        System.debug(
            LoggingLevel.FINE,
            'TriggerMetrics: Ended metrics for ' +
                handler +
                ', Operation: ' +
                operation +
                ', SObject: ' +
                sObjectType +
                ', ExecutionId: ' +
                executionId +
                ', ParentId: ' +
                snapshot.parentExecutionId
        );

        if (metricsBuffer.size() >= 95) {
            flushMetrics();
        }
    }

    public static void flushMetrics() {
        if (metricsBuffer.isEmpty()) {
            return;
        }

        // Only flush if we're at the root level (depth == 1 or globalExecutionStack is empty)
        if (!globalExecutionStack.isEmpty()) {
            // Not at root level, let the parent handle flushing
            return;
        }

        try {
            System.debug(LoggingLevel.FINE, 'TriggerMetrics: Flushing ' + metricsBuffer.size() + ' metrics');
            Database.insert(metricsBuffer, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error inserting metrics: ' + e.getMessage());
        } finally {
            metricsBuffer.clear();
        }
    }

    /**
     * Gets a formatted string representation of the execution tree
     */
    public static String getFormattedExecutionTree(String transactionId) {
        List<TriggerMetric__c> metrics = getExecutionTree(transactionId);
        if (metrics.isEmpty()) {
            return 'No metrics available for the current transaction.';
        }

        // Build parent to children map
        Map<String, List<TriggerMetric__c>> parentToChildren = new Map<String, List<TriggerMetric__c>>();
        for (TriggerMetric__c metric : metrics) {
            String parentId = metric.ParentExecutionId__c;
            if (parentId == null) {
                parentId = 'ROOT';
            }

            if (!parentToChildren.containsKey(parentId)) {
                parentToChildren.put(parentId, new List<TriggerMetric__c>());
            }
            parentToChildren.get(parentId).add(metric);
        }

        // Format tree
        String result = 'Transaction: ' + transactionId + '\n';
        result += formatTreeBranch(parentToChildren, 'ROOT', 0);
        return result;
    }

    private static List<TriggerMetric__c> getExecutionTree(String transactionId) {
        return [
            SELECT
                Handler__c,
                Operation__c,
                SObjectType__c,
                RecordCount__c,
                StartTime__c,
                EndTime__c,
                ExecutionTime__c,
                CPUTime__c,
                DMLRows__c,
                QueryRows__c,
                TransactionId__c,
                ExecutionId__c,
                ParentExecutionId__c,
                Depth__c,
                Sequence__c
            FROM TriggerMetric__c
            WHERE TransactionId__c = :transactionId
            ORDER BY Sequence__c ASC
        ];
    }

    private static String formatTreeBranch(
        Map<String, List<TriggerMetric__c>> parentToChildren,
        String parentId,
        Integer level
    ) {
        String result = '';

        if (!parentToChildren.containsKey(parentId)) {
            return result;
        }

        for (TriggerMetric__c metric : parentToChildren.get(parentId)) {
            // Indent based on level
            String indent = '';
            for (Integer i = 0; i < level; i++) {
                indent += '  ';
            }

            result +=
                indent +
                '├─ ' +
                metric.Handler__c +
                ' [' +
                metric.Operation__c +
                ', ' +
                metric.SObjectType__c +
                '] - ' +
                metric.ExecutionTime__c +
                'ms, CPU: ' +
                metric.CPUTime__c +
                'ms, DML: ' +
                metric.DMLRows__c +
                ', Query: ' +
                metric.QueryRows__c +
                '\n';

            // Recursively format children
            result += formatTreeBranch(parentToChildren, metric.ExecutionId__c, level + 1);
        }

        return result;
    }

    private static String generateMetricKey(String handler, String operation, String sObjectName, String executionId) {
        return handler + '|' + operation + '|' + sObjectName + '|' + executionId;
    }
}
