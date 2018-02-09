/**
 * @flow
 */

import * as React from 'react';
import * as t from './types.js';

/**
 * A set of typed k-v pairs which workflow views and processes can access.
 */
export type Context = {[name: string]: mixed};

/**
 * A pattern over the context, describes a subset of context keys and values.
 */
export type ContextType = {[name: string]: t.TypeImage};

/**
 * A pattern over the context, describes a subset of context keys and values.
 */
export type ContextTypeShape = {[name: string]: t.TypeImage};

/**
 * A query which results in a Data.
 */
export type Query<Data> = string;

/**
 * Data needed to a view or a process to execute.
 */
export type Data = mixed;

/**
 * View is a piece of UI which operates in some context, requires some data and
 * can prodice an updated context.
 */
export type View<Data> = $ReadOnly<{
  type: 'View',
  id: string,

  requires: ContextTypeShape,
  provides: ContextTypeShape,

  /**
   * Define data requirements for a given context.
   */
  query(Context): Query<Data>,

  /**
   * Render UI given the current context and data.
   */
  render(Context, Data, (Context) => void): React.Element<*>,
}>;

/**
 * Process is some procedure which doesn't require user participation.
 */
export type Process<Data> = $ReadOnly<{
  type: 'Process',
  id: string,

  requires: ContextTypeShape,
  provides: ContextTypeShape,

  /**
   * Define data requirements for a given context.
   */
  query(Context): Query<Data>,

  /**
   * Execute process given the current context and data.
   */
  execute(Context, Data): Promise<Context>,
}>;

/**
 * Guard wraps an action and executes it only if a query specified evaluates to
 * `true` in the current context.
 */
export type Guard = $ReadOnly<{
  type: 'Guard',
  id: string,
  requires: ContextTypeShape,

  /**
   * Query which determines if action can be executed.
   */
  query(Context): Query<boolean>,
}>;

/**
 * A sequence of actions executed in order.
 */
export type Sequence = $ReadOnly<{
  type: 'Sequence',
  id: string,
  sequence: Array<Action>,
}>;

/**
 * A set of actions, one of them can be executed at once.
 */
export type Choice = $ReadOnly<{
  type: 'Choice',
  id: string,
  choice: Array<Action>,
}>;

export type Action = View<*> | Process<*> | Guard | Sequence | Choice;
