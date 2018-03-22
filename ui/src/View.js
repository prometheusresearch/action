/**
 * @flow
 */

import * as React from 'react';
import * as ReactNative from 'react-native-web';
import * as W from 'workflow';
import type {State} from 'workflow';
import {Error} from './Error.js';
import {ScreenTitle} from './ScreenTitle.js';

type P = {
  state: State,
};

export function View(props: P) {
  const data = W.getData(props.state);
  const title = W.getTitle(props.state);
  return (
    <ReactNative.View>
      <ScreenTitle>{title}</ScreenTitle>
      <ReactNative.View>
        <ReactNative.Text>{JSON.stringify(data, null, 2)}</ReactNative.Text>
      </ReactNative.View>
    </ReactNative.View>
  );
}
