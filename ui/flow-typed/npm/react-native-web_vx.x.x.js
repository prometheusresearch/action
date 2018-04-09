// flow-typed signature: 1e731e5029989485c3f09d0fd85d11c1
// flow-typed version: <<STUB>>/react-native-web_v0.4.0/flow_v0.65.0

/**
 * This is an autogenerated libdef stub for:
 *
 *   'react-native-web'
 *
 * Fill this stub out by replacing all the `any` types.
 *
 * Once filled out, we encourage you to share your work with the
 * community by sending a pull request to:
 * https://github.com/flowtype/flow-typed
 */

declare module 'react-native-web' {
  import type {ComponentType} from 'react';

  declare export var View: ComponentType<any>;
  declare export var ScrollView: ComponentType<any>;
  declare export var TouchableOpacity: ComponentType<any>;
  declare export var TouchableHighlight: ComponentType<any>;
  declare export var Button: ComponentType<any>;
  declare export var Text: ComponentType<any>;
  declare export var StyleSheet: {
    create: Function,
  };
  declare export function processColor(string, number): string;
}
