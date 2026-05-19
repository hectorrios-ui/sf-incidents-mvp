import { LightningElement, track } from 'lwc';

const STATUS = Object.freeze({
    CHECKING:  'checking',
    GRANTED:   'granted',
    DENIED:    'denied',
    PROMPT:    'prompt',
    ERROR:     'error',
    UNSUPPORTED: 'unsupported'
});

export default class NF_MediaDeviceHelper extends LightningElement {
    @track micStatus = STATUS.CHECKING;
    @track speakerStatus = STATUS.CHECKING;
    @track errorDetail = '';
    @track devices = [];
    @track showTroubleshoot = false;
    @track lastChecked = '';

    get isChecking() {
        return this.micStatus === STATUS.CHECKING;
    }

    get isMicGranted() {
        return this.micStatus === STATUS.GRANTED;
    }

    get isMicDenied() {
        return this.micStatus === STATUS.DENIED;
    }

    get isMicPrompt() {
        return this.micStatus === STATUS.PROMPT;
    }

    get isSpeakerGranted() {
        return this.speakerStatus === STATUS.GRANTED;
    }

    get isSpeakerUnsupported() {
        return this.speakerStatus === STATUS.UNSUPPORTED;
    }

    get hasError() {
        return this.micStatus === STATUS.ERROR || this.speakerStatus === STATUS.ERROR;
    }

    get allGranted() {
        return this.isMicGranted && (this.isSpeakerGranted || this.isSpeakerUnsupported);
    }

    get micStatusLabel() {
        const labels = {
            [STATUS.CHECKING]:    'Checking…',
            [STATUS.GRANTED]:     'Allowed',
            [STATUS.DENIED]:      'Blocked',
            [STATUS.PROMPT]:      'Not yet requested',
            [STATUS.ERROR]:       'Error',
            [STATUS.UNSUPPORTED]: 'Not supported'
        };
        return labels[this.micStatus] ?? 'Unknown';
    }

    get speakerStatusLabel() {
        const labels = {
            [STATUS.CHECKING]:    'Checking…',
            [STATUS.GRANTED]:     'Available',
            [STATUS.DENIED]:      'Blocked',
            [STATUS.PROMPT]:      'Not yet requested',
            [STATUS.ERROR]:       'Error',
            [STATUS.UNSUPPORTED]: 'Browser does not support speaker selection'
        };
        return labels[this.speakerStatus] ?? 'Unknown';
    }

    get micIconName() {
        return this.isMicGranted ? 'utility:success' : 'utility:error';
    }

    get micIconVariant() {
        return this.isMicGranted ? 'success' : 'error';
    }

    get speakerIconName() {
        if (this.isSpeakerGranted) return 'utility:success';
        if (this.isSpeakerUnsupported) return 'utility:warning';
        return 'utility:error';
    }

    get speakerIconVariant() {
        if (this.isSpeakerGranted) return 'success';
        if (this.isSpeakerUnsupported) return 'warning';
        return 'error';
    }

    get hasMicDevices() {
        return this.devices.some(d => d.kind === 'audioinput');
    }

    get hasSpeakerDevices() {
        return this.devices.some(d => d.kind === 'audiooutput');
    }

    get micDevices() {
        return this.devices
            .filter(d => d.kind === 'audioinput')
            .map((d, i) => ({
                id: d.deviceId,
                label: d.label || `Microphone ${i + 1}`
            }));
    }

    get speakerDevices() {
        return this.devices
            .filter(d => d.kind === 'audiooutput')
            .map((d, i) => ({
                id: d.deviceId,
                label: d.label || `Speaker ${i + 1}`
            }));
    }

    get statusBadgeClass() {
        const base = 'slds-badge slds-var-m-left_x-small';
        return this.allGranted
            ? `${base} slds-theme_success`
            : `${base} slds-theme_error`;
    }

    get overallStatusLabel() {
        return this.allGranted ? 'Ready' : 'Action Needed';
    }

    connectedCallback() {
        this.checkPermissions();
    }

    async checkPermissions() {
        this.micStatus = STATUS.CHECKING;
        this.speakerStatus = STATUS.CHECKING;
        this.errorDetail = '';

        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.micStatus = STATUS.UNSUPPORTED;
            this.speakerStatus = STATUS.UNSUPPORTED;
            this.errorDetail = 'This browser does not support media device access. Use a supported browser such as Chrome or Edge.';
            return;
        }

        try {
            await this._checkMicPermission();
        } catch (e) {
            this.micStatus = STATUS.ERROR;
            this.errorDetail = e.message;
        }

        try {
            await this._checkSpeakerDevices();
        } catch (e) {
            this.speakerStatus = STATUS.UNSUPPORTED;
        }

        this.lastChecked = new Date().toLocaleTimeString();
    }

    async _checkMicPermission() {
        if (navigator.permissions && navigator.permissions.query) {
            try {
                const result = await navigator.permissions.query({ name: 'microphone' });
                if (result.state === 'granted') {
                    this.micStatus = STATUS.GRANTED;
                    await this._enumerateDevices();
                    return;
                }
                if (result.state === 'denied') {
                    this.micStatus = STATUS.DENIED;
                    return;
                }
            } catch (_) {
                // permissions.query not supported for microphone in some browsers
            }
        }
        this.micStatus = STATUS.PROMPT;
    }

    async _checkSpeakerDevices() {
        if (typeof navigator.mediaDevices.enumerateDevices !== 'function') {
            this.speakerStatus = STATUS.UNSUPPORTED;
            return;
        }

        const devices = await navigator.mediaDevices.enumerateDevices();
        const outputs = devices.filter(d => d.kind === 'audiooutput');

        if (outputs.length > 0) {
            this.speakerStatus = STATUS.GRANTED;
        } else {
            this.speakerStatus = STATUS.UNSUPPORTED;
        }
    }

    async _enumerateDevices() {
        try {
            const raw = await navigator.mediaDevices.enumerateDevices();
            this.devices = raw
                .filter(d => d.kind === 'audioinput' || d.kind === 'audiooutput')
                .map(d => ({ deviceId: d.deviceId, kind: d.kind, label: d.label }));
        } catch (_) {
            this.devices = [];
        }
    }

    async handleRequestAccess() {
        this.micStatus = STATUS.CHECKING;
        this.errorDetail = '';

        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            stream.getTracks().forEach(t => t.stop());

            this.micStatus = STATUS.GRANTED;
            await this._enumerateDevices();
            await this._checkSpeakerDevices();
            this.lastChecked = new Date().toLocaleTimeString();
        } catch (err) {
            if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
                this.micStatus = STATUS.DENIED;
                this.errorDetail =
                    'Permission was denied. Click the lock/site-settings icon in your browser address bar, ' +
                    'set Microphone to "Allow", then reload the page.';
            } else if (err.name === 'NotFoundError') {
                this.micStatus = STATUS.ERROR;
                this.errorDetail = 'No microphone found. Please connect a headset or microphone and try again.';
            } else if (err.name === 'NotReadableError' || err.name === 'AbortError') {
                this.micStatus = STATUS.ERROR;
                this.errorDetail =
                    'The microphone is in use by another application or cannot be accessed. ' +
                    'Close other apps using the mic and try again.';
            } else {
                this.micStatus = STATUS.ERROR;
                this.errorDetail = `${err.name}: ${err.message}`;
            }
        }
    }

    handleRecheck() {
        this.checkPermissions();
    }

    handleToggleTroubleshoot() {
        this.showTroubleshoot = !this.showTroubleshoot;
    }
}
