import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateAndDeploy from '@salesforce/apex/NF_FigmalwcController.generateAndDeploy';
import generateFromZip from '@salesforce/apex/NF_FigmalwcController.generateFromZip';

const MAX_ZIP_BYTES = 3 * 1024 * 1024; // 3 MB — keeps under Apex heap when base64 + extracted images

const PROMPT_TEMPLATE = `Create and deploy an LWC POC from this Figma design.

Figma URL: {{FIGMA_URL}}
{{FRAME_LINE}}{{PREFIX_LINE}}
Use a production-quality design-to-code approach:
- Semantic HTML structure, SLDS where appropriate
- Clean LWC naming and folder structure
- Create the component(s) in force-app/main/default/lwc and deploy (fix any deploy errors and retry until success)

Open the Figma URL using the cursor-ide-browser MCP (browser_navigate → browser_take_screenshot) to see the actual design before building. Do NOT fetch the URL as plain HTML. If the page requires login or renders blank, ask me for a screenshot.`;

export default class NFigmaToLwcRequest extends LightningElement {
    @track figmaUrl = '';
    @track frameName = '';
    @track prefix = 'nF_';
    @track showPrompt = false;
    @track isGenerating = false;
    @track resultMessage = '';
    @track resultSuccess = false;
    @track mode = 'figma';
    @track zipBase64 = null;
    @track zipFileName = '';
    @track zipFileSize = 0;
    @track zipTooLarge = false;
    @track statusText = '';

    get isFigmaMode() { return this.mode === 'figma'; }
    get isUploadMode() { return this.mode === 'upload'; }
    get figmaVariant() { return this.mode === 'figma' ? 'brand' : 'neutral'; }
    get uploadVariant() { return this.mode === 'upload' ? 'brand' : 'neutral'; }
    get showPromptLabel() { return this.showPrompt ? 'Hide prompt' : 'Show prompt'; }

    get generateButtonLabel() {
        if (this.isGenerating) return 'Generating…';
        return this.isUploadMode ? 'Generate from ZIP & Deploy' : 'Generate & Deploy';
    }

    get isGenerateDisabled() {
        if (this.isGenerating) return true;
        if (this.isUploadMode) return !this.zipBase64 || this.zipTooLarge;
        return false;
    }

    get resultMessageClass() {
        return this.resultSuccess
            ? 'slds-m-top_small slds-p-around_small slds-theme_success'
            : 'slds-m-top_small slds-p-around_small slds-theme_error';
    }

    get zipSizeLabel() {
        if (!this.zipFileSize) return '';
        const mb = this.zipFileSize / (1024 * 1024);
        return mb >= 1 ? (mb.toFixed(1) + ' MB') : (Math.round(this.zipFileSize / 1024) + ' KB');
    }

    get zipFileRowClass() {
        const base = 'slds-text-body_small slds-m-bottom_x-small ';
        return base + (this.zipTooLarge ? 'slds-text-color_error' : 'slds-text-color_success');
    }

    handleModeFigma() { this.mode = 'figma'; }
    handleModeUpload() { this.mode = 'upload'; }
    handleUrlChange(e) { this.figmaUrl = e.detail.value; }
    handleFrameNameChange(e) { this.frameName = e.detail.value; }
    handlePrefixChange(e) { this.prefix = e.detail.value || 'nF_'; }
    handleShowPrompt() { this.showPrompt = !this.showPrompt; }

    handleFileChange(e) {
        const files = e.target.files;
        if (!files || files.length === 0) {
            this.zipBase64 = null;
            this.zipFileName = '';
            this.zipFileSize = 0;
            this.zipTooLarge = false;
            return;
        }
        const file = files[0];
        this.zipFileName = file.name;
        this.zipFileSize = file.size;
        this.zipTooLarge = file.size > MAX_ZIP_BYTES;
        if (this.zipTooLarge) {
            this.zipBase64 = null;
            this.dispatchEvent(new ShowToastEvent({
                title: 'File too large',
                message: 'Keep the ZIP under 3 MB to avoid server limits. Use fewer/smaller images or lower resolution.',
                variant: 'error'
            }));
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = reader.result;
            this.zipBase64 = dataUrl.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    get promptText() {
        const url = (this.figmaUrl || '').trim();
        const frame = (this.frameName || '').trim();
        const pre = (this.prefix || '').trim();
        return PROMPT_TEMPLATE
            .replace('{{FIGMA_URL}}', url || '<paste Figma URL here>')
            .replace('{{FRAME_LINE}}', frame ? `Frame/component name: ${frame}\n` : '')
            .replace('{{PREFIX_LINE}}', pre ? `LWC name prefix: ${pre}\n` : '');
    }

    async handleGenerateDeploy() {
        this.resultMessage = '';
        this.isGenerating = true;
        this.statusText = this.isUploadMode
            ? 'Extracting images from ZIP and sending to AI…'
            : 'Fetching design from Figma and sending to AI…';

        try {
            let result;
            if (this.isUploadMode) {
                result = await generateFromZip({
                    zipBase64: this.zipBase64,
                    frameName: this.frameName,
                    prefix: this.prefix
                });
            } else {
                result = await generateAndDeploy({
                    figmaUrl: this.figmaUrl,
                    frameName: this.frameName,
                    prefix: this.prefix
                });
            }
            this.resultSuccess = result.success;
            this.resultMessage = result.message || (result.success ? 'Deployed: ' + result.componentName : 'Failed');
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Done', message: result.message, variant: 'success' }));
            }
        } catch (e) {
            this.resultSuccess = false;
            this.resultMessage = e.body?.message || e.message || 'Request failed';
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.resultMessage, variant: 'error' }));
        } finally {
            this.isGenerating = false;
            this.statusText = '';
        }
    }

    async handleCopyPrompt() {
        try {
            await navigator.clipboard.writeText(this.promptText);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copied!',
                message: 'Paste the prompt into Cursor to generate and deploy the LWC.',
                variant: 'success'
            }));
        } catch (err) {
            this.showPrompt = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copy failed',
                message: 'Clipboard not available — copy the text below manually.',
                variant: 'warning'
            }));
        }
    }
}
