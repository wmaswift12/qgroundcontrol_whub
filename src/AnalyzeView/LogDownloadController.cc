/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "LogDownloadController.h"
#include "AppSettings.h"
#include "LogEntry.h"
#include "MAVLinkProtocol.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"
#include "QmlObjectListModel.h"
#include "SettingsManager.h"
#include "Vehicle.h"
#include "QGCMAVLink.h"
#include <mavlink.h>

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QTimer>

#include <QFile>
#include <QStandardPaths>
#include <QDir>
#include <QTextStream>

#include <QtMath>
#include <QDebug>

#include <QTimer>
#include <QFileSystemWatcher>

#include <QDir>
#include <QFileInfoList>


QGC_LOGGING_CATEGORY(LogDownloadControllerLog, "qgc.analyzeview.logdownloadcontroller")

Q_APPLICATION_STATIC(LogDownloadController, _logDownloadControllerInstance);

LogDownloadController::LogDownloadController(QObject *parent)
    : QObject(parent)
    , _timer(new QTimer(this))
    , _logEntriesModel(new QmlObjectListModel(this))
{
    // qCDebug(LogDownloadControllerLog) << Q_FUNC_INFO << this;

    (void) connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged, this, &LogDownloadController::_setActiveVehicle);
    (void) connect(_timer, &QTimer::timeout, this, &LogDownloadController::_processDownload);

    _timer->setSingleShot(false);

    _setActiveVehicle(MultiVehicleManager::instance()->activeVehicle());
}

LogDownloadController::~LogDownloadController()
{
    // qCDebug(LogDownloadControllerLog) << Q_FUNC_INFO << this;
}

LogDownloadController *LogDownloadController::instance()
{
    return _logDownloadControllerInstance();
}

void LogDownloadController::download(const QString &path)
{
    const QString dir = path.isEmpty() ? SettingsManager::instance()->appSettings()->logSavePath() : path;
    _downloadToDirectory(dir);
}

void LogDownloadController::_downloadToDirectory(const QString &dir)
{
    _receivedAllEntries();

    _downloadData.reset();

    _downloadPath = dir;
    if (_downloadPath.isEmpty()) {
        return;
    }

    if (!_downloadPath.endsWith(QDir::separator())) {
        _downloadPath += QDir::separator();
    }

    QGCLogEntry *const log = _getNextSelected();
    if (log) {
        log->setStatus(tr("Waiting"));
    }

    _setDownloading(true);
    _receivedAllData();
}

void LogDownloadController::_processDownload()
{
    if (_requestingLogEntries) {
        _findMissingEntries();
    } else if (_downloadingLogs) {
        _findMissingData();
    }
}

void LogDownloadController::_findMissingEntries()
{
    const int num_logs = _logEntriesModel->count();
    int start = -1;
    int end = -1;
    for (int i = 0; i < num_logs; i++) {
        const QGCLogEntry *const entry = _logEntriesModel->value<const QGCLogEntry*>(i);
        if (!entry) {
            continue;
        }

        if (!entry->received()) {
            if (start < 0) {
                start = i;
            } else {
                end = i;
            }
        } else if (start >= 0) {
            break;
        }
    }

    if (start < 0) {
        _receivedAllEntries();
        return;
    }

    if (_retries++ > 2) {
        for (int i = 0; i < num_logs; i++) {
            QGCLogEntry *const entry = _logEntriesModel->value<QGCLogEntry*>(i);
            if (entry && !entry->received()) {
                entry->setStatus(tr("Error"));
            }
        }

        _receivedAllEntries();
        qCWarning(LogDownloadControllerLog) << "Too many errors retreiving log list. Giving up.";
        return;
    }

    if (end < 0) {
        end = start;
    }

    start += _apmOffset;
    end += _apmOffset;

    _requestLogList(static_cast<uint32_t>(start), static_cast<uint32_t>(end));
}

void LogDownloadController::_setActiveVehicle(Vehicle *vehicle)
{
    if (vehicle == _vehicle) {
        return;
    }

    if (_vehicle) {
        _logEntriesModel->clearAndDeleteContents();
        (void) disconnect(_vehicle, &Vehicle::logEntry, this, &LogDownloadController::_logEntry);
        (void) disconnect(_vehicle, &Vehicle::logData,  this, &LogDownloadController::_logData);
    }

    _vehicle = vehicle;

    if (_vehicle) {
        (void) connect(_vehicle, &Vehicle::logEntry, this, &LogDownloadController::_logEntry);
        (void) connect(_vehicle, &Vehicle::logData,  this, &LogDownloadController::_logData);
    }
}

void LogDownloadController::_logEntry(uint32_t time_utc, uint32_t size, uint16_t id, uint16_t num_logs, uint16_t last_log_num)
{
    Q_UNUSED(last_log_num);

    if (!_requestingLogEntries) {
        return;
    }

    if ((_logEntriesModel->count() == 0) && (num_logs > 0)) {
        if (_vehicle->firmwareType() == MAV_AUTOPILOT_ARDUPILOTMEGA) {
            // APM ID starts at 1
            _apmOffset = 1;
        }

        for (int i = 0; i < num_logs; i++) {
            QGCLogEntry *const entry = new QGCLogEntry(i);
            _logEntriesModel->append(entry);
        }
    }

    if (num_logs > 0) {
        if ((size > 0) || (_vehicle->firmwareType() != MAV_AUTOPILOT_ARDUPILOTMEGA)) {
            id -= _apmOffset;
            if (id < _logEntriesModel->count()) {
                QGCLogEntry *const entry = _logEntriesModel->value<QGCLogEntry*>(id);
                entry->setSize(size);
                entry->setTime(QDateTime::fromSecsSinceEpoch(time_utc));
                entry->setReceived(true);
                entry->setStatus(tr("Available"));
            } else {
                qCWarning(LogDownloadControllerLog) << "Received log entry for out-of-bound index:" << id;
            }
        }
    } else {
        _receivedAllEntries();
    }

    _retries = 0;

    if (_entriesComplete()) {
        _receivedAllEntries();
    } else {
        _timer->start(kTimeOutMs);
    }
}

void LogDownloadController::_receivedAllEntries()
{
    _timer->stop();
    _setListing(false);
}

bool LogDownloadController::_entriesComplete() const
{
    const int num_logs = _logEntriesModel->count();
    for (int i = 0; i < num_logs; i++) {
        const QGCLogEntry *const entry = _logEntriesModel->value<const QGCLogEntry*>(i);
        if (!entry) {
            continue;
        }

        if (!entry->received()) {
            return false;
        }
    }

    return true;
}

void LogDownloadController::_logData(uint32_t ofs, uint16_t id, uint8_t count, const uint8_t *data)
{
    if (!_downloadingLogs || !_downloadData) {
        return;
    }

    id -= _apmOffset;
    if (_downloadData->ID != id) {
        qCWarning(LogDownloadControllerLog) << "Received log data for wrong log";
        return;
    }

    if ((ofs % MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN) != 0) {
        qCWarning(LogDownloadControllerLog) << "Ignored misaligned incoming packet @" << ofs;
        return;
    }

    bool result = false;
    if (ofs <= _downloadData->entry->size()) {
        const uint32_t chunk = ofs / LogDownloadData::kChunkSize;
        // qCDebug(LogDownloadControllerLog) << "Received data - Offset:" << ofs << "Chunk:" << chunk;
        if (chunk != _downloadData->current_chunk) {
            qCWarning(LogDownloadControllerLog) << "Ignored packet for out of order chunk actual:expected" << chunk << _downloadData->current_chunk;
            return;
        }

        const uint16_t bin = (ofs - (chunk * LogDownloadData::kChunkSize)) / MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN;
        if (bin >= _downloadData->chunk_table.size()) {
            qCWarning(LogDownloadControllerLog) << "Out of range bin received";
        } else {
            _downloadData->chunk_table.setBit(bin);
        }

        if (_downloadData->file.pos() != ofs) {
            if (!_downloadData->file.seek(ofs)) {
                qCWarning(LogDownloadControllerLog) << "Error while seeking log file offset";
                return;
            }
        }

        if (_downloadData->file.write(reinterpret_cast<const char*>(data), count)) {
            _downloadData->written += count;
            _downloadData->rate_bytes += count;
            _updateDataRate();

            result = true;
            _retries = 0;

            _timer->start(kTimeOutMs);
            if (_logComplete()) {
                _downloadData->entry->setStatus(tr("Downloaded"));
                _receivedAllData();
            } else if (_chunkComplete()) {
                _downloadData->advanceChunk();
                _requestLogData(_downloadData->ID,
                                _downloadData->current_chunk * LogDownloadData::kChunkSize,
                                _downloadData->chunk_table.size() * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN);
            } else if ((bin < (_downloadData->chunk_table.size() - 1)) && _downloadData->chunk_table.at(bin + 1)) {
                // Likely to be grabbing fragments and got to the end of a gap
                _findMissingData();
            }
        } else {
            qCWarning(LogDownloadControllerLog) << "Error while writing log file chunk";
        }
    } else {
        qCWarning(LogDownloadControllerLog) << "Received log offset greater than expected";
    }

    if (!result) {
        _downloadData->entry->setStatus(tr("Error"));
    }
}

void LogDownloadController::_findMissingData()
{
    if (_logComplete()) {
        _receivedAllData();
        return;
    }

    if (_chunkComplete()) {
        _downloadData->advanceChunk();
    }

    _retries++;

    _updateDataRate();

    uint16_t start = 0, end = 0;
    const int size = _downloadData->chunk_table.size();
    for (; start < size; start++) {
        if (!_downloadData->chunk_table.testBit(start)) {
            break;
        }
    }

    for (end = start; end < size; end++) {
        if (_downloadData->chunk_table.testBit(end)) {
            break;
        }
    }

    const uint32_t pos = (_downloadData->current_chunk * LogDownloadData::kChunkSize) + (start * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN);
    const uint32_t len = (end - start) * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN;
    _requestLogData(_downloadData->ID, pos, len, _retries);
}

void LogDownloadController::_updateDataRate()
{
    if (_downloadData->elapsed.elapsed() < kGUIRateMs) {
        return;
    }

    const qreal rate = _downloadData->rate_bytes / (_downloadData->elapsed.elapsed() / 1000.0);
    _downloadData->rate_avg = (_downloadData->rate_avg * 0.95) + (rate * 0.05);
    _downloadData->rate_bytes = 0;

    const QString status = QStringLiteral("%1 (%2/s)").arg(qgcApp()->bigSizeToString(_downloadData->written),
                                                           qgcApp()->bigSizeToString(_downloadData->rate_avg));

    _downloadData->entry->setStatus(status);
    _downloadData->elapsed.start();
}

bool LogDownloadController::_chunkComplete() const
{
    return _downloadData->chunkEquals(true);
}

bool LogDownloadController::_logComplete() const
{
    return (_chunkComplete() && ((_downloadData->current_chunk + 1) == _downloadData->numChunks()));
}

void LogDownloadController::_receivedAllData()
{
    _timer->stop();
    if (_prepareLogDownload()) {
        _requestLogData(_downloadData->ID, 0, _downloadData->chunk_table.size() * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN);
        _timer->start(kTimeOutMs);
    } else {
        _resetSelection();
        _setDownloading(false);
    }
}

bool LogDownloadController::_prepareLogDownload()
{
    _downloadData.reset();

    QGCLogEntry *const entry = _getNextSelected();
    if (!entry) {
        return false;
    }

    entry->setSelected(false);
    emit selectionChanged();

    const QString ftime = (entry->time().date().year() >= 2010) ? entry->time().toString(QStringLiteral("yyyy-M-d-hh-mm-ss")) : QStringLiteral("UnknownDate");

    _downloadData = std::make_unique<LogDownloadData>(entry);
    _downloadData->filename = QStringLiteral("log_") + QString::number(entry->id()) + "_" + ftime;

    if (_vehicle->firmwareType() == MAV_AUTOPILOT_PX4) {
        const QString loggerParam = QStringLiteral("SYS_LOGGER");
        ParameterManager *const parameterManager = _vehicle->parameterManager();
        if (parameterManager->parameterExists(ParameterManager::defaultComponentId, loggerParam) && parameterManager->getParameter(ParameterManager::defaultComponentId, loggerParam)->rawValue().toInt() == 0) {
            _downloadData->filename += ".px4log";
        } else {
            _downloadData->filename += ".ulg";
        }
    } else {
        _downloadData->filename += ".bin";
    }

    _downloadData->file.setFileName(_downloadPath + _downloadData->filename);

    if (_downloadData->file.exists()) {
        uint32_t numDups = 0;
        const QStringList filename_spl = _downloadData->filename.split('.');
        do {
            numDups += 1;
            const QString filename = filename_spl[0] + '_' + QString::number(numDups) + '.' + filename_spl[1];
            _downloadData->file.setFileName(filename);
        } while ( _downloadData->file.exists());
    }

    bool result = false;
    if (!_downloadData->file.open(QIODevice::WriteOnly)) {
        qCWarning(LogDownloadControllerLog) << "Failed to create log file:" <<  _downloadData->filename;
    } else if (!_downloadData->file.resize(entry->size())) {
        qCWarning(LogDownloadControllerLog) << "Failed to allocate space for log file:" <<  _downloadData->filename;
    } else {
        _downloadData->current_chunk = 0;
        _downloadData->chunk_table = QBitArray(_downloadData->chunkBins(), false);
        _downloadData->elapsed.start();
        result = true;
    }

    if (!result) {
        if (_downloadData->file.exists()) {
            (void) _downloadData->file.remove();
        }

        _downloadData->entry->setStatus(QStringLiteral("Error"));
        _downloadData.reset();
    }

    return result;
}

void LogDownloadController::refresh()
{
    _logEntriesModel->clearAndDeleteContents();
    _requestLogList(0, 0xffff);
}

QGCLogEntry *LogDownloadController::_getNextSelected() const
{
    const int numLogs = _logEntriesModel->count();
    for (int i = 0; i < numLogs; i++) {
        QGCLogEntry *const entry = _logEntriesModel->value<QGCLogEntry*>(i);
        if (!entry) {
            continue;
        }

        if (entry->selected()) {
           return entry;
        }
    }

    return nullptr;
}

void LogDownloadController::cancel()
{
    _requestLogEnd();
    _receivedAllEntries();

    if (_downloadData) {
        _downloadData->entry->setStatus(QStringLiteral("Canceled"));
        if (_downloadData->file.exists()) {
            (void) _downloadData->file.remove();
        }

        _downloadData.reset();
    }

    _resetSelection(true);
    _setDownloading(false);
}

void LogDownloadController::_resetSelection(bool canceled)
{
    const int num_logs = _logEntriesModel->count();
    for (int i = 0; i < num_logs; i++) {
        QGCLogEntry *const entry = _logEntriesModel->value<QGCLogEntry*>(i);
        if (!entry) {
            continue;
        }

        if (entry->selected()) {
            if (canceled) {
                entry->setStatus(tr("Canceled"));
            }
            entry->setSelected(false);
        }
    }

    emit selectionChanged();
}

void LogDownloadController::eraseAll()
{
    if (!_vehicle) {
        qCWarning(LogDownloadControllerLog) << "Vehicle Unavailable";
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        qCWarning(LogDownloadControllerLog) << "Link Unavailable";
        return;
    }

    mavlink_message_t msg{};
    (void) mavlink_msg_log_erase_pack_chan(
        MAVLinkProtocol::instance()->getSystemId(),
        MAVLinkProtocol::getComponentId(),
        sharedLink->mavlinkChannel(),
        &msg,
        _vehicle->id(),
        _vehicle->defaultComponentId()
    );

    if (!_vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg)) {
        qCWarning(LogDownloadControllerLog) << "Failed to send";
        return;
    }

    refresh();
}

void LogDownloadController::_requestLogList(uint32_t start, uint32_t end)
{
    if (!_vehicle) {
        qCWarning(LogDownloadControllerLog) << "Vehicle Unavailable";
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        qCWarning(LogDownloadControllerLog) << "Link Unavailable";
        return;
    }

    mavlink_message_t msg{};
    (void) mavlink_msg_log_request_list_pack_chan(
        MAVLinkProtocol::instance()->getSystemId(),
        MAVLinkProtocol::getComponentId(),
        sharedLink->mavlinkChannel(),
        &msg,
        _vehicle->id(),
        _vehicle->defaultComponentId(),
        start,
        end
    );

    if (!_vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg)) {
        qCWarning(LogDownloadControllerLog) << "Failed to send";
        return;
    }

    qCDebug(LogDownloadControllerLog) << "Request log entry list (" << start << "through" << end << ")";
    _setListing(true);
    _timer->start(kRequestLogListTimeoutMs);
}

void LogDownloadController::_requestLogData(uint16_t id, uint32_t offset, uint32_t count, int retryCount)
{
    if (!_vehicle) {
        qCWarning(LogDownloadControllerLog) << "Vehicle Unavailable";
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        qCWarning(LogDownloadControllerLog) << "Link Unavailable";
        return;
    }

    id += _apmOffset;
    qCDebug(LogDownloadControllerLog) << "Request log data (id:" << id << "offset:" << offset << "size:" << count << "retryCount" << retryCount << ")";

    mavlink_message_t msg{};
    (void) mavlink_msg_log_request_data_pack_chan(
        MAVLinkProtocol::instance()->getSystemId(),
        MAVLinkProtocol::getComponentId(),
        sharedLink->mavlinkChannel(),
        &msg,
        _vehicle->id(),
        _vehicle->defaultComponentId(),
        id,
        offset,
        count
    );

    if (!_vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg)) {
        qCWarning(LogDownloadControllerLog) << "Failed to send";
    }
}

void LogDownloadController::_requestLogEnd()
{
    if (!_vehicle) {
        qCWarning(LogDownloadControllerLog) << "Vehicle Unavailable";
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        qCWarning(LogDownloadControllerLog) << "Link Unavailable";
        return;
    }

    mavlink_message_t msg{};
    (void) mavlink_msg_log_request_end_pack_chan(
        MAVLinkProtocol::instance()->getSystemId(),
        MAVLinkProtocol::getComponentId(),
        sharedLink->mavlinkChannel(),
        &msg,
        _vehicle->id(),
        _vehicle->defaultComponentId()
    );

    if (!_vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg)) {
        qCWarning(LogDownloadControllerLog) << "Failed to send";
    }
}

void LogDownloadController::_setDownloading(bool active)
{
    if (_downloadingLogs != active) {
        _downloadingLogs = active;
        _vehicle->vehicleLinkManager()->setCommunicationLostEnabled(!active);
        emit downloadingLogsChanged();
    }
}

void LogDownloadController::_setListing(bool active)
{
    if (_requestingLogEntries != active) {
        _requestingLogEntries = active;
        _vehicle->vehicleLinkManager()->setCommunicationLostEnabled(!active);
        emit requestingListChanged();
    }
}

void LogDownloadController::saveHistoryDataToFile(
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
) {
    QString safeSpray = sprayVolume.isEmpty() ? "0.000" : sprayVolume;
    QString safeFlow  = flowRate.isEmpty()    ? "0.000" : flowRate;
    QString safeArea = sprayArea.isEmpty()    ? "0.000" : sprayArea;

    QString filePath = "/home/wm_lenovo/Documents/QGC_History/HistoryData.txt";
    QFile file(filePath);

        // Ensure directory exists
    QDir dir = QFileInfo(filePath).absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    bool fileExists = QFile::exists(filePath);

    // Read existing content to check for duplicates
    QStringList existingLines;
    if (fileExists) {
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&file);
            while (!in.atEnd()) {
                existingLines << in.readLine().trimmed();
            }
            file.close();
        }
    }

    // Create new row
    QString newRow = date + "," + startTime + "," + endTime + "," +
                     totalTime + "," + distance + "," + battery + "," + fuel + "," +
                     safeSpray + "," + safeFlow + "," + safeArea;

     // Check for duplicate by startTime (unique per flight) ===
    QString key = date + "," + startTime;
    bool duplicateFound = false;

    for (const QString& line : existingLines) {
        if (line.startsWith(key)) {   // only compare date + startTime
            duplicateFound = true;
            break;
        }
    }

    if (duplicateFound) {
        qDebug() << "Duplicate flight skipped (same start time):" << key;
        return;
    }

    // Append row if unique
    if (!file.open(QIODevice::Append | QIODevice::Text)) {
        qWarning() << "Failed to open file for writing:" << filePath;
        return;
    }

    QTextStream out(&file);

    // Write header if new file
    if (!fileExists) {
        out << "Date,Flight Start Time,Flight End Time,Total Flight Time,"
               "Flight Distance,Remaining Battery (%),Fuel Consumed,"
               "Spray Volume (L),Flow Rate (mL/min), Spray Area (ha)\n";
    }

    out << newRow << "\n";
    file.close();
}

void LogDownloadController::loadHistoryFile()
{
    QString filePath = "/home/wm_lenovo/Documents/QGC_History/HistoryData.txt";
    QFile file(filePath);

    if (!file.exists()) {
        qWarning() << "History file not found:" << filePath;
        _historyText = "History file not found.";
        emit historyTextChanged();
        return;
    }

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open history file:" << file.errorString();
        _historyText = "Failed to open history file.";
        emit historyTextChanged();
        return;
    }

    QTextStream in(&file);
    _historyText = in.readAll();
    file.close();

    emit historyTextChanged();
}

void LogDownloadController::loadCsvFile(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file:" << filePath;
        return;
    }

    _csvLines.clear();
    while (!file.atEnd()) {
        _csvLines.append(file.readLine().trimmed());
    }
    file.close();

    parseCsvSummary();
}

void LogDownloadController::parseCsvSummary()
{
    if (_csvLines.isEmpty())
        return;

    QString header = _csvLines.first();
    QStringList columns = header.split(',');

    int idxTimestamp      = columns.indexOf("Timestamp");
    int idxFlightTime     = columns.indexOf("flightTime");
    int idxFlightDistance = columns.indexOf("flightDistance");
    int idxBattery        = columns.indexOf("battery0.percentRemaining");
    int idxFuel           = columns.indexOf("efi.fuelConsumed");
    int idxClockDate      = columns.indexOf("clock.currentDate");
    
    int idxSprayVolume = columns.indexOf("sprayVolume");
    int idxFlowRate    = columns.indexOf("flowRate");
    int idxSprayArea   = columns.indexOf("sprayArea");

    // Flight state variables
    QString startDate, startTime;
    QString endTime, totalTime, distance, battery, fuel;
    QString sprayVolume, flowRate, sprayArea;
    bool inFlight = false;

    for (int i = 1; i < _csvLines.size(); ++i) {
        QStringList values = _csvLines[i].split(',');

        QString ts   = (idxTimestamp      >= 0 && idxTimestamp      < values.size()) ? values[idxTimestamp] : "";
        QString ftime= (idxFlightTime     >= 0 && idxFlightTime     < values.size()) ? values[idxFlightTime] : "";
        QString dist = (idxFlightDistance >= 0 && idxFlightDistance < values.size()) ? values[idxFlightDistance] : "";
        QString batt = (idxBattery        >= 0 && idxBattery        < values.size()) ? values[idxBattery] : "";
        QString fu   = (idxFuel           >= 0 && idxFuel           < values.size()) ? values[idxFuel] : "";
        QString cdate= (idxClockDate      >= 0 && idxClockDate      < values.size()) ? values[idxClockDate] : "";
        
        sprayVolume = (idxSprayVolume >= 0 && idxSprayVolume < values.size()) ? values[idxSprayVolume] : "";
        flowRate    = (idxFlowRate    >= 0 && idxFlowRate    < values.size()) ? values[idxFlowRate]    : "";
        sprayArea   = (idxSprayArea   >= 0 && idxSprayArea   < values.size()) ? values[idxSprayArea]   : "";


        // Detect new flight when flightTime resets
        if (!ftime.isEmpty() && ftime == "00:00:00") {
            if (inFlight) {
                // Finalize previous flight
                bool valid = (!totalTime.isEmpty() && totalTime != "00:00:00" &&
                              !distance.isEmpty() && distance.toDouble() > 0.1);

                if (valid) {
                    saveHistoryDataToFile(
                        startDate, startTime, endTime, totalTime,
                        distance, battery, fuel, sprayVolume, flowRate, sprayArea
                    );
                }
            }

            // Start new flight
            startDate = cdate;
            startTime = ts;
            inFlight = true;
        }

        // Always update last-known values for ongoing flight
        endTime   = ts;
        totalTime = ftime;
        distance  = dist;
        battery   = batt;
        fuel      = fu;
    }

    // Save last flight if valid
    if (inFlight) {
        bool valid = (!totalTime.isEmpty() && totalTime != "00:00:00" &&
                      !distance.isEmpty() && distance.toDouble() > 0.1);

        if (valid) {
            saveHistoryDataToFile(
                startDate, startTime, endTime, totalTime,
                distance, battery, fuel, sprayVolume, flowRate, sprayArea
            );
        }
    }
}

void LogDownloadController::loadAllCsvFiles(const QString& folderPath)
{
    QDir dir(folderPath);
    if (!dir.exists()) {
        qWarning() << "Folder not found:" << folderPath;
        return;
    }

    QStringList filters;
    filters << "*.csv";
    QFileInfoList fileList = dir.entryInfoList(filters, QDir::Files, QDir::Name);

    if (fileList.isEmpty()) {
        qWarning() << "No CSV files found in folder:" << folderPath;
        return;
    }

    // Clear history text before reloading
    _historyText.clear();

    for (const QFileInfo& fileInfo : fileList) {
        QString filePath = fileInfo.absoluteFilePath();
        qDebug() << "Processing CSV file:" << filePath;

        // Load + parse CSV (this will internally call saveHistoryDataToFile for each detected flight)
        loadCsvFile(filePath);
    }

    // Finally, reload history file and show in QML
    loadHistoryFile();
}  