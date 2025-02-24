/**
 * Created by sonal on 2025-02-14.
 */

public class TriggerMetrics {
    @TestVisible
    private static Boolean isMetricsEnabled = null;

    @TestVisible
    private static Map<String, MetricSnapshot> activeSnapshots = new Map<String, MetricSnapshot>();

    private static List<TriggerMetric__c> metricsBuffer = new List<TriggerMetric__c>();

    private class MetricSnapshot {
        Long startTime;
        Integer cpuStart;
        Integer dmlStart;
        Integer queryStart;
        Integer recordCount;
    }

    public static Boolean isMetricsEnabled() {
        if (isMetricsEnabled == null) {
            TriggerSettings__c settings = TriggerSettings__c.getInstance();
            isMetricsEnabled = settings?.IsMetricsEnabled__c == true;
        }
        return isMetricsEnabled;
    }

    public static void startMetrics(String handler, String operation, String sObjectType, Integer count) {
        if (!isMetricsEnabled()) {
            return;
        }

        String key = generateMetricKey(handler, operation, sObjectType);
        MetricSnapshot snapshot = new MetricSnapshot();
        snapshot.startTime = System.now().getTime();
        snapshot.cpuStart = Limits.getCpuTime();
        snapshot.dmlStart = Limits.getDmlRows();
        snapshot.queryStart = Limits.getQueryRows();
        snapshot.recordCount = count;

        activeSnapshots.put(key, snapshot);
    }

    public static void endMetrics(String handler, String operation, String sObjectType) {
        if (!isMetricsEnabled()) {
            return;
        }

        String key = generateMetricKey(handler, operation, sObjectType);
        MetricSnapshot snapshot = activeSnapshots.remove(key);
        if (snapshot == null) {
            return;
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
                QueryRows__c = Limits.getQueryRows() - snapshot.queryStart
            )
        );

        if (metricsBuffer.size() >= 95) {
            flushMetrics();
        }
    }

    public static void flushMetrics() {
        if (metricsBuffer.isEmpty()) {
            return;
        }

        try {
            Database.insert(metricsBuffer, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error inserting metrics: ' + e.getMessage());
        } finally {
            metricsBuffer.clear();
        }
    }

    private static String generateMetricKey(String handler, String operation, String sObjectName) {
        return handler + '|' + operation + '|' + sObjectName;
    }
}
