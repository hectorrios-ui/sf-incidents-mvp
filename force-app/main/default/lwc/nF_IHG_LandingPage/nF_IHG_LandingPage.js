import { LightningElement } from 'lwc';

const TILES = [
    {
        id: 'sccView',
        title: 'IHG SCC View Screens',
        description: 'Includes the Case and Account record page',
        icon: 'utility:refresh'
    },
    {
        id: 'hotelView',
        title: 'IHG Hotel View Screens',
        description: 'Includes the Case and Account record page',
        icon: 'utility:account'
    },
    {
        id: 'cxboContact',
        title: 'Enhanced CXBO Contact',
        description: 'Custom record layout for the entire CXBO record',
        icon: 'utility:contact'
    },
    {
        id: 'caseCreation',
        title: 'Case Creation LWC',
        description: 'Custom Lightning Web Component to support search & create Cases',
        icon: 'utility:case'
    },
    {
        id: 'caseCode',
        title: 'Case Code LWC',
        description: 'Custom Lightning Web Component to support the entry of Case Codes',
        icon: 'utility:code'
    },
    {
        id: 'aiSummary',
        title: 'AI Summary LWC',
        description: 'Custom Lightning Web Component to support summary a record',
        icon: 'utility:einstein'
    }
];

export default class NF_IHG_landingPage extends LightningElement {
    tiles = TILES;

    handleTileClick(event) {
        const tileId = event.currentTarget.dataset.tile;
        this.dispatchEvent(new CustomEvent('tileselect', { detail: { tileId } }));
    }

    handleTileKeyPress(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.handleTileClick(event);
        }
    }
}
