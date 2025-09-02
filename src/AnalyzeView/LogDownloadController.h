/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#ifndef LOGDOWNLOADCONTROLLER_H
#define LOGDOWNLOADCONTROLLER_H

#include <QString>
#include <QStringList>

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtQmlIntegration/QtQmlIntegration>

#include <QDateTime>
#include <QVariantList>

Q_DECLARE_LOGGING_CATEGORY(LogDownloadControllerLog)

struct LogDownloadData;
class QGCLogEntry;
class QmlObjectListModel;
class QTimer;
class QThread;
class Vehicle;
class LogDownloadTest;

class LogDownloadController : public QObject
{
    Q_OBJECT
    // QML_ELEMENT
    // QML_SINGLETON
    Q_MOC_INCLUDE("Vehicle.h")
    Q_MOC_INCLUDE("QmlObjectListModel.h")
    Q_PROPERTY(QmlObjectListModel *model          READ _getModel            CONSTANT)
    Q_PROPERTY(bool               requestingList  READ _getRequestingList   NOTIFY requestingListChanged)
    Q_PROPERTY(bool               downloadingLogs READ _getDownloadingLogs  NOTIFY downloadingLogsChanged)
    Q_PROPERTY(int lastBatteryUsage READ lastBatteryUsage NOTIFY lastBatteryUsageChanged)
    Q_PROPERTY(QString lastFlightTime READ lastFlightTime NOTIFY lastFlightTimeChanged)
    Q_PROPERTY(QString historyText READ historyText NOTIFY historyTextChanged)
    Q_PROPERTY(QString csvText READ csvText NOTIFY csvTextChanged)

    Q_PROPERTY(QString flightDate READ flightDate NOTIFY flightSummaryChanged)
    Q_PROPERTY(QString flightStartTime READ flightStartTime NOTIFY flightSummaryChanged)
    Q_PROPERTY(QString flightEndTime READ flightEndTime NOTIFY flightSummaryChanged)
    Q_PROPERTY(QString totalFlightTime READ totalFlightTime NOTIFY flightSummaryChanged)
    Q_PROPERTY(QString flightDistance READ flightDistance NOTIFY flightSummaryChanged)
    Q_PROPERTY(QString remainingBattery READ remainingBattery NOTIFY flightSummaryChanged)
    Q_PROPERTY(QString fuelConsumed READ fuelConsumed NOTIFY flightSummaryChanged)
    Q_PROPERTY(QStringList flightSummaries READ flightSummaries NOTIFY flightSummariesChanged)

    friend class LogDownloadTest;

public:
    explicit LogDownloadController(QObject *parent = nullptr);
    ~LogDownloadController();

    static LogDownloadController *instance();

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void download(const QString &path = QString());
    Q_INVOKABLE void eraseAll();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void saveHistoryDataToFile(
        const QString& date,
        const QString& startTime,
        const QString& endTime,
        const QString& totalTime,
        const QString& distance,
        const QString& battery,
        const QString& fuel,
        const QString& sprayVolume,
        const QString& flowRate,
        const QString& sprayArea
    );

    Q_INVOKABLE void loadCsvFile(const QString &filePath);
    Q_INVOKABLE void loadAllCsvFiles(const QString& folderPath);
    Q_INVOKABLE QVariantList parseHistory(const QString& text);
    Q_INVOKABLE QVariantMap rebuildSeries(const QVariantList& points);
    Q_INVOKABLE QVariantMap computeSummary(const QVariantList& points);

    int lastBatteryUsage() const { return _lastBatteryUsage; }
    QString lastFlightTime() const { return _lastFlightTime; }

    QString historyText() const { return _historyText; }
    Q_INVOKABLE void loadHistoryFile();
    QString csvText() const { return _csvText; }


    QString flightDate() const { return _flightDate; }
    QString flightStartTime() const { return _flightStartTime; }
    QString flightEndTime() const { return _flightEndTime; }
    QString totalFlightTime() const { return _totalFlightTime; }
    QString flightDistance() const { return _flightDistance; }
    QString remainingBattery() const { return _remainingBattery; }
    QString fuelConsumed() const { return _fuelConsumed; }
    QStringList flightSummaries() const { return _flightSummaries; }
   

signals:
    void requestingListChanged();
    void downloadingLogsChanged();
    void selectionChanged();
    void lastBatteryUsageChanged();
    void lastFlightTimeChanged();
    void historyTextChanged();
    void csvTextChanged();
    void flightSummaryChanged();
    void flightSummariesChanged();

private slots:
    void _setActiveVehicle(Vehicle *vehicle);
    void _logEntry(uint32_t time_utc, uint32_t size, uint16_t id, uint16_t num_logs, uint16_t last_log_num);
    void _logData(uint32_t ofs, uint16_t id, uint8_t count, const uint8_t *data);
    void _processDownload();

private:
    QmlObjectListModel *_getModel() const { return _logEntriesModel; }
    bool _getRequestingList() const { return _requestingLogEntries; }
    bool _getDownloadingLogs() const { return _downloadingLogs; }

    bool _chunkComplete() const;
    bool _entriesComplete() const;
    bool _logComplete() const;
    bool _prepareLogDownload();
    void _downloadToDirectory(const QString &dir);
    void _findMissingData();
    void _findMissingEntries();
    void _receivedAllData();
    void _receivedAllEntries();
    void _requestLogData(uint16_t id, uint32_t offset, uint32_t count, int retryCount = 0);
    void _requestLogList(uint32_t start, uint32_t end);
    void _requestLogEnd();
    void _resetSelection(bool canceled = false);
    void _setDownloading(bool active);
    void _setListing(bool active);
    void _updateDataRate();

    QGCLogEntry *_getNextSelected() const;

    QTimer *_timer = nullptr;
    QmlObjectListModel *_logEntriesModel = nullptr;

    bool _downloadingLogs = false;
    bool _requestingLogEntries = false;
    int _apmOffset = 0;
    int _retries = 0;
    int _lastBatteryUsage = 0;
    std::unique_ptr<LogDownloadData> _downloadData;
    QString _downloadPath;
    QString _lastFlightTime;
    Vehicle *_vehicle = nullptr;

    QString _historyText;
    QString _historyFilePath;
    void _updateHistoryText();
    QString _csvText;

    void parseCsvSummary();
    QStringList _csvLines;
    QStringList _flightSummaries;

    QString _flightDate;
    QString _flightStartTime;
    QString _flightEndTime;
    QString _totalFlightTime;
    QString _flightDistance;
    QString _remainingBattery;
    QString _fuelConsumed;

    struct HistoryPoint {
        qint64 tMs;
        double distance;
        double battery;
        double flightTime;
        double fuel;
        double sprayVolume;
        double flowRate;
        double sprayArea;
    };

    static constexpr uint32_t kTimeOutMs = 500;
    static constexpr uint32_t kGUIRateMs = 17; ///< 1000ms / 60fps
    static constexpr uint32_t kRequestLogListTimeoutMs = 5000;
};

#endif
