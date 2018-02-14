/**
 * @flow
 */

import * as React from 'react';
import * as W from 'workflow';
import {View, Button, Text, TouchableOpacity} from 'react-native-web';

function Breadcrumb({
  ui,
  trace,
  onClick,
}: {
  ui: UI,
  trace: Array<{ui: UI, frame: W.Frame<UI>}>,
  onClick: ({ui: UI, frame: W.Frame<UI>}) => *,
}) {
  const items = [];
  for (const item of trace) {
    const onPress = item.frame != null ? () => onClick(item) : null;
    items.push({title: item.ui.title, onPress});
  }

  const buttons = items.map((item, idx) => {
    const style = {padding: 10, fontWeight: '200'};
    return (
      <TouchableOpacity key={idx} onPress={item.onPress}>
        <Text style={style}>{item.title}</Text>
      </TouchableOpacity>
    );
  });

  buttons.push(
    <Text key="current" style={{padding: 10, fontWeight: '600'}}>
      {ui.title}
    </Text>,
  );

  return <View style={{flexDirection: 'row'}}>{buttons}</View>;
}

function Next({
  next,
  onClick,
}: {
  next: Array<{ui: UI, frame: W.Frame<UI>}>,
  onClick: ({ui: UI, frame: W.Frame<UI>}) => *,
}) {
  const items = [];
  for (const item of next) {
    const onPress = item.frame != null ? () => onClick(item) : null;
    items.push({title: item.ui.title, onPress});
  }

  const buttons = items.map((item, idx) => {
    const style = {padding: 10, fontWeight: '200'};
    return (
      <TouchableOpacity key={idx} onPress={item.onPress}>
        <Text style={style}>{item.title}</Text>
      </TouchableOpacity>
    );
  });

  return <View style={{flexDirection: 'row'}}>{buttons}</View>;
}

export type UI = {
  title: string,
  render(
    context: W.Context,
    data: W.DataSet,
    onContext: (W.Context) => *,
  ): React.Element<*>,
};

type Props = {
  workflow: W.Workflow<UI>,
};

type State = {
  frame: W.Frame<UI>,
  info: ?W.Info<UI>,
};

export class Workflow extends React.Component<Props, State> {
  config: W.Config;

  waitForData = async (query: W.Query) => {
    const resp = await fetch(`http://localhost:3001/graphql?query=query{${query}}`);
    const data = await resp.json();
    return data.data;
  };

  constructor(props: Props) {
    super(props);
    this.config = {waitForData: this.waitForData};
    this.state = {
      frame: W.init(props.workflow),
      info: null,
    };
  }

  onContext = async (nextContext: W.Context) => {
    const {info, frame} = await W.nextToInteraction(
      this.config,
      nextContext,
      this.state.frame,
    );
    if (info != null) {
      this.setState({info, frame});
    }
  };

  onBreadcrumbClick = async ({ui, frame: nextFrame}: {ui: UI, frame: W.Frame<UI>}) => {
    const {info, frame} = await W.runToInteraction(this.config, nextFrame);
    if (info != null) {
      this.setState({info, frame});
    }
  };

  async componentDidMount() {
    const {info, frame} = await W.runToInteraction(this.config, this.state.frame);
    if (info != null) {
      this.setState({info, frame});
    }
  }

  render() {
    const {info} = this.state;
    if (info == null) {
      return (
        <View style={{flex: 1, padding: 10}}>
          <Text>Loading...</Text>
        </View>
      );
    }
    const {context, data, ui, prev, next} = info;
    const title = ui.title;
    return (
      <View style={{flex: 1}}>
        <View>
          <Breadcrumb ui={ui} trace={prev} onClick={this.onBreadcrumbClick} />
        </View>
        <View>
          <Next next={next} onClick={this.onBreadcrumbClick} />
        </View>
        <View style={{padding: 10, flex: 1}}>
          <View style={{paddingBottom: 10}}>
            <Text style={{fontWeight: '600', fontSize: 18}}>{title}</Text>
          </View>
          <View style={{flex: 1}}>{ui.render(context, data, this.onContext)}</View>
        </View>
      </View>
    );
  }
}
