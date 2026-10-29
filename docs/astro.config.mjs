// @ts-check
// The shared max-models docs setup (@max-models/starlight-theme): served at
// https://max-models.github.io/whereami/. whereami is a set of shell scripts: no API reference.
import { defineDocs } from '@max-models/starlight-theme';

export default defineDocs({
	repo: 'whereami',
	title: 'whereami',
	description: 'Detect the current HPC machine and load the right environment modules.',
	nav: [
		{ label: 'Getting started', link: '/getting-started/installation/' },
		{ label: 'Usage', link: '/usage/whereami/' },
	],
	sidebar: [
		{ label: 'Getting started', items: [{ label: 'Installation', slug: 'getting-started/installation' }] },
		{
			label: 'Usage',
			items: [
				{ label: 'whereami', slug: 'usage/whereami' },
				{ label: 'load_modules', slug: 'usage/load-modules' },
				{ label: 'modules.json', slug: 'usage/modules-json' },
				{ label: 'edit_modules', slug: 'usage/edit-modules' },
			],
		},
	],
});
