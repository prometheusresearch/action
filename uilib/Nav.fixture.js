/**
 * @flow
 */

import * as React from 'react';
import {TouchableOpacity} from 'react-native-web';
import {MdExitToApp} from 'react-icons/lib/md';

import {Nav, NavButton} from './Nav.js';
import {OutlineButton} from './OutlineButton.js';
import * as cfg from './config.js';
import {type FixtureList, createShowcaseList} from './FixtureUtil.js';

const displayName = Nav.displayName || Nav.name;
const ShowcaseList = createShowcaseList(displayName);

const renderNav = ({outlineColor: textColor}) => [
  <NavButton textColor={textColor} title="Home" />,
  <NavButton textColor={textColor} title="Documentation" />,
  <NavButton textColor={textColor} title="Publications" />,
  <OutlineButton strokeColor={textColor} label="Try Action" />,
];

const renderNavExtra = ({outlineColor: textColor}) => [
  <TouchableOpacity>
    <MdExitToApp />
  </TouchableOpacity>,
];

const noNav = {
  title: 'No Nav',
  element: <Nav breadcrumb={[]} />,
};

const withNav = {
  title: 'With Nav',
  element: <Nav breadcrumb={[]} renderNav={renderNav} />,
};

const withNavExtra = {
  title: 'With Nav',
  element: <Nav breadcrumb={[]} renderNav={renderNav} renderNavExtra={renderNavExtra} />,
};

const withBreadcrumb = {
  title: 'With Breadcrumb',
  element: (
    <Nav
      renderNav={renderNav}
      breadcrumb={[
        {title: 'Documentation'},
        {title: 'API References'},
        {title: 'Combinators'},
      ]}
    />
  ),
};

const customOutlineColor = {
  title: 'Custom Outline Color',
  element: (
    <Nav
      renderNav={renderNav}
      outlineColor={cfg.color.indigo}
      breadcrumb={[
        {title: 'Documentation'},
        {title: 'API References'},
        {title: 'Combinators'},
      ]}
    />
  ),
};

const fixtures: FixtureList = [
  {
    component: ShowcaseList,
    props: {
      rows: [noNav, withNav, withNavExtra, withBreadcrumb, customOutlineColor],
    },
  },
  ,
];

export default fixtures;
