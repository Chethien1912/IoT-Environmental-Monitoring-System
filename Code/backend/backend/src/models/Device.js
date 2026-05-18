// Model Device quan ly thong tin thiet bi, owner, trang thai online va telemetry moi nhat.
const db = require('../config/database');

class Device {
  static normalizeFiniteNumber(value, fallback) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  static clampFiniteNumber(value, fallback, min, max) {
    const normalized = this.normalizeFiniteNumber(value, fallback);
    return Math.min(Math.max(normalized, min), max);
  }

  static normalizeTimeText(value, fallback) {
    const text = String(value || '').trim();
    return /^\d{2}:\d{2}$/.test(text) ? text : fallback;
  }

  static defaultAutomationSettings() {
    return {
      relay1: {
        threshold: 35,
        scheduleEnabled: false,
        startTime: '06:00',
        endTime: '22:00'
      },
      relay2: {
        threshold: 70,
        scheduleEnabled: false,
        startTime: '06:00',
        endTime: '22:00'
      },
      relay3: {
        coThreshold: 50,
        no2Threshold: 0.5,
        scheduleEnabled: false,
        startTime: '06:00',
        endTime: '22:00'
      },
      buzzer: {
        temperatureThreshold: 38,
        humidityThreshold: 80,
        coThreshold: 100,
        no2Threshold: 1,
        scheduleEnabled: false,
        startTime: '00:00',
        endTime: '23:59'
      }
    };
  }

  static normalizeAutomationSettings(input) {
    const defaults = this.defaultAutomationSettings();
    const source = input && typeof input === 'object' ? input : {};
    const relay1 = source.relay1 && typeof source.relay1 === 'object' ? source.relay1 : {};
    const relay2 = source.relay2 && typeof source.relay2 === 'object' ? source.relay2 : {};
    const relay3 = source.relay3 && typeof source.relay3 === 'object' ? source.relay3 : {};
    const buzzer = source.buzzer && typeof source.buzzer === 'object' ? source.buzzer : {};

    return {
      relay1: {
        threshold: this.clampFiniteNumber(
          relay1.threshold,
          defaults.relay1.threshold,
          0,
          80
        ),
        scheduleEnabled: Boolean(relay1.scheduleEnabled ?? defaults.relay1.scheduleEnabled),
        startTime: this.normalizeTimeText(relay1.startTime, defaults.relay1.startTime),
        endTime: this.normalizeTimeText(relay1.endTime, defaults.relay1.endTime)
      },
      relay2: {
        threshold: this.clampFiniteNumber(
          relay2.threshold,
          defaults.relay2.threshold,
          0,
          100
        ),
        scheduleEnabled: Boolean(relay2.scheduleEnabled ?? defaults.relay2.scheduleEnabled),
        startTime: this.normalizeTimeText(relay2.startTime, defaults.relay2.startTime),
        endTime: this.normalizeTimeText(relay2.endTime, defaults.relay2.endTime)
      },
      relay3: {
        coThreshold: this.clampFiniteNumber(
          relay3.coThreshold,
          defaults.relay3.coThreshold,
          0,
          1000
        ),
        no2Threshold: this.clampFiniteNumber(
          relay3.no2Threshold,
          defaults.relay3.no2Threshold,
          0,
          15
        ),
        scheduleEnabled: Boolean(relay3.scheduleEnabled ?? defaults.relay3.scheduleEnabled),
        startTime: this.normalizeTimeText(relay3.startTime, defaults.relay3.startTime),
        endTime: this.normalizeTimeText(relay3.endTime, defaults.relay3.endTime)
      },
      buzzer: {
        temperatureThreshold: this.clampFiniteNumber(
          buzzer.temperatureThreshold,
          defaults.buzzer.temperatureThreshold,
          0,
          80
        ),
        humidityThreshold: this.clampFiniteNumber(
          buzzer.humidityThreshold,
          defaults.buzzer.humidityThreshold,
          0,
          100
        ),
        coThreshold: this.clampFiniteNumber(
          buzzer.coThreshold,
          defaults.buzzer.coThreshold,
          0,
          1000
        ),
        no2Threshold: this.clampFiniteNumber(
          buzzer.no2Threshold,
          defaults.buzzer.no2Threshold,
          0,
          15
        ),
        scheduleEnabled: Boolean(
          buzzer.scheduleEnabled ?? defaults.buzzer.scheduleEnabled
        ),
        startTime: this.normalizeTimeText(buzzer.startTime, defaults.buzzer.startTime),
        endTime: this.normalizeTimeText(buzzer.endTime, defaults.buzzer.endTime)
      }
    };
  }

  static normalizeHardwareId(hardwareId) {
    const raw = String(hardwareId || '').trim();
    if (!raw) {
      return null;
    }

    const compact = raw.replace(/[^a-fA-F0-9]/g, '').toUpperCase();
    if (compact.length === 12) {
      return compact.match(/.{1,2}/g).join(':');
    }

    return raw.toUpperCase();
  }

  static compactHardwareId(hardwareId) {
    const raw = String(hardwareId || '').trim();
    if (!raw) {
      return null;
    }

    const compact = raw.replace(/[^a-fA-F0-9]/g, '').toUpperCase();
    return compact.length ? compact : null;
  }

  static mapRow(row) {
    if (!row) {
      return null;
    }

    return {
      ...row,
      is_online: Boolean(row.is_online),
      desired_relay1: Boolean(row.desired_relay1),
      desired_relay2: Boolean(row.desired_relay2),
      desired_relay3: Boolean(row.desired_relay3),
      desired_relay4: Boolean(row.desired_relay4),
      control_mode: row.control_mode === 'auto' ? 'auto' : 'manual',
      owner: row.owner_id
        ? {
            id: row.owner_id,
            username: row.owner_username
          }
        : undefined,
      last_telemetry: row.last_telemetry ? JSON.parse(row.last_telemetry) : null,
      pending_rtc_payload: row.pending_rtc_payload ? JSON.parse(row.pending_rtc_payload) : null,
      automation_settings: this.normalizeAutomationSettings(
        row.automation_settings ? JSON.parse(row.automation_settings) : null
      )
    };
  }

  static findById(id) {
    const row = db
      .prepare(
        `
        SELECT devices.*, users.username AS owner_username
        FROM devices
        JOIN users ON users.id = devices.owner_id
        WHERE devices.id = ?
        `
      )
      .get(id);

    return this.mapRow(row);
  }

  static findByHardwareId(hardwareId) {
    const normalized = this.normalizeHardwareId(hardwareId);
    const compact = this.compactHardwareId(hardwareId);
    if (!normalized || !compact) {
      return null;
    }

    const row = db
      .prepare(
        `
        SELECT devices.*, users.username AS owner_username
        FROM devices
        JOIN users ON users.id = devices.owner_id
        WHERE devices.hardware_id = ?
           OR REPLACE(devices.hardware_id, ':', '') = ?
        ORDER BY CASE WHEN devices.hardware_id = ? THEN 0 ELSE 1 END, devices.created_at DESC
        LIMIT 1
        `
      )
      .get(normalized, compact, normalized);

    return this.mapRow(row);
  }

  static findByOwner(ownerId) {
    const rows = db
      .prepare(
        `
        SELECT devices.*, users.username AS owner_username
        FROM devices
        JOIN users ON users.id = devices.owner_id
        WHERE devices.owner_id = ?
        ORDER BY devices.created_at DESC
        `
      )
      .all(ownerId);

    return rows.map((row) => this.mapRow(row));
  }

  static listAll() {
    const rows = db
      .prepare(
        `
        SELECT devices.*, users.username AS owner_username
        FROM devices
        JOIN users ON users.id = devices.owner_id
        ORDER BY devices.created_at DESC
        `
      )
      .all();

    return rows.map((row) => this.mapRow(row));
  }

  static create({ id, name, type = 'esp32', ownerId, deviceSecretHash, hardwareId = null }) {
    const normalizedHardwareId = this.normalizeHardwareId(hardwareId);
    db.prepare(
      `
      INSERT INTO devices (id, name, type, owner_id, device_secret_hash, hardware_id)
      VALUES (?, ?, ?, ?, ?, ?)
      `
    ).run(id, name, type, ownerId, deviceSecretHash, normalizedHardwareId);

    return this.findById(id);
  }

  static update(id, { name, type, ownerId, hardwareId, passwordHash }) {
    const existing = db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
    if (!existing) {
      return null;
    }

    db.prepare(
      `
      UPDATE devices
      SET name = ?, type = ?, owner_id = ?, hardware_id = ?, device_secret_hash = ?
      WHERE id = ?
      `
    ).run(
      name ?? existing.name,
      type ?? existing.type,
      ownerId ?? existing.owner_id,
      hardwareId ?? existing.hardware_id,
      passwordHash ?? existing.device_secret_hash,
      id
    );

    return this.findById(id);
  }

  static delete(id) {
    return db.prepare('DELETE FROM devices WHERE id = ?').run(id);
  }

  static setOnline(id, isOnline, lastSeen = null) {
    db.prepare(
      `
      UPDATE devices
      SET is_online = ?, last_seen = COALESCE(?, last_seen)
      WHERE id = ?
      `
    ).run(isOnline ? 1 : 0, lastSeen, id);

    return this.findById(id);
  }

  static saveLastTelemetry(id, payload, receivedAt) {
    db.prepare(
      `
      UPDATE devices
      SET last_seen = ?, last_telemetry = ?, is_online = 1
      WHERE id = ?
      `
    ).run(receivedAt, JSON.stringify(payload), id);

    return this.findById(id);
  }

  static updateControlState(id, {
    desiredRelay1,
    desiredRelay2,
    desiredRelay3,
    desiredRelay4
  }) {
    const existing = db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
    if (!existing) {
      return null;
    }

    db.prepare(
      `
      UPDATE devices
      SET desired_relay1 = ?, desired_relay2 = ?, desired_relay3 = ?, desired_relay4 = ?
      WHERE id = ?
      `
    ).run(
      desiredRelay1 == null ? existing.desired_relay1 : desiredRelay1 ? 1 : 0,
      desiredRelay2 == null ? existing.desired_relay2 : desiredRelay2 ? 1 : 0,
      desiredRelay3 == null ? existing.desired_relay3 : desiredRelay3 ? 1 : 0,
      desiredRelay4 == null ? existing.desired_relay4 : desiredRelay4 ? 1 : 0,
      id
    );

    return this.findById(id);
  }

  static updateAutomationConfig(id, { controlMode, automationSettings }) {
    const existing = db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
    if (!existing) {
      return null;
    }

    const nextMode = controlMode === 'auto' ? 'auto' : 'manual';
    const nextSettings = this.normalizeAutomationSettings(automationSettings);
    db.prepare(
      `
      UPDATE devices
      SET control_mode = ?, automation_settings = ?
      WHERE id = ?
      `
    ).run(nextMode, JSON.stringify(nextSettings), id);

    return this.findById(id);
  }

  static syncHardwareRuntime(id, { desiredRelay1, desiredRelay2, desiredRelay3, controlMode, thresholds }) {
    const existing = this.findById(id);
    if (!existing) {
      return null;
    }

    const currentSettings = this.normalizeAutomationSettings(existing.automation_settings);
    const thresholdSource = thresholds && typeof thresholds === 'object' ? thresholds : {};
    const nextSettings = this.normalizeAutomationSettings({
      ...currentSettings,
      relay1: {
        ...currentSettings.relay1,
        threshold: thresholdSource.temp
          ?? thresholdSource.temperature
          ?? thresholdSource.temperatureThreshold
          ?? currentSettings.relay1.threshold
      },
      relay2: {
        ...currentSettings.relay2,
        threshold: thresholdSource.humid
          ?? thresholdSource.humidity
          ?? thresholdSource.humidityThreshold
          ?? currentSettings.relay2.threshold
      },
      relay3: {
        ...currentSettings.relay3,
        coThreshold:
          thresholdSource.co
          ?? thresholdSource.coThreshold
          ?? currentSettings.relay3.coThreshold,
        no2Threshold:
          thresholdSource.no2
          ?? thresholdSource.no2Threshold
          ?? currentSettings.relay3.no2Threshold
      }
    });

    db.prepare(
      `
      UPDATE devices
      SET desired_relay1 = ?,
          desired_relay2 = ?,
          desired_relay3 = ?,
          control_mode = ?,
          automation_settings = ?
      WHERE id = ?
      `
    ).run(
      desiredRelay1 == null ? (existing.desired_relay1 ? 1 : 0) : desiredRelay1 ? 1 : 0,
      desiredRelay2 == null ? (existing.desired_relay2 ? 1 : 0) : desiredRelay2 ? 1 : 0,
      desiredRelay3 == null ? (existing.desired_relay3 ? 1 : 0) : desiredRelay3 ? 1 : 0,
      controlMode === 'auto' ? 'auto' : 'manual',
      JSON.stringify(nextSettings),
      id
    );

    return this.findById(id);
  }

  static bindHardwareId(id, hardwareId) {
    const normalizedHardwareId = this.normalizeHardwareId(hardwareId);
    db.prepare(
      `
      UPDATE devices
      SET hardware_id = ?
      WHERE id = ?
      `
    ).run(normalizedHardwareId, id);

    return this.findById(id);
  }

  static queueRtcSync(id, rtcPayload) {
    const existing = db.prepare('SELECT pending_rtc_version FROM devices WHERE id = ?').get(id);
    if (!existing) {
      return null;
    }

    const nextVersion = Number(existing.pending_rtc_version || 0) + 1;
    db.prepare(
      `
      UPDATE devices
      SET pending_rtc_payload = ?, pending_rtc_version = ?
      WHERE id = ?
      `
    ).run(JSON.stringify(rtcPayload), nextVersion, id);

    return this.findById(id);
  }

  static clearRtcSync(id, expectedVersion = null) {
    const existing = db
      .prepare('SELECT pending_rtc_version FROM devices WHERE id = ?')
      .get(id);
    if (!existing) {
      return null;
    }

    if (expectedVersion != null && Number(existing.pending_rtc_version || 0) != expectedVersion) {
      return this.findById(id);
    }

    db.prepare(
      `
      UPDATE devices
      SET pending_rtc_payload = NULL
      WHERE id = ?
      `
    ).run(id);

    return this.findById(id);
  }

  static verifyOwnership(deviceId, userId) {
    const row = db
      .prepare('SELECT 1 FROM devices WHERE id = ? AND owner_id = ?')
      .get(deviceId, userId);
    return Boolean(row);
  }

  static listStaleOnline(beforeIso) {
    const rows = db
      .prepare(
        'SELECT id FROM devices WHERE is_online = 1 AND last_seen IS NOT NULL AND last_seen < ?'
      )
      .all(beforeIso);
    return rows.map((row) => row.id);
  }
}

module.exports = Device;
