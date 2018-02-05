// flow-typed signature: c11347aa666782615909b62fc982a539
// flow-typed version: <<STUB>>/pg_v7.4.1/flow_v0.64.0

/**
 * This is an autogenerated libdef stub for:
 *
 *   'pg'
 *
 * Fill this stub out by replacing all the `any` types.
 *
 * Once filled out, we encourage you to share your work with the
 * community by sending a pull request to:
 * https://github.com/flowtype/flow-typed
 */

declare module 'pg' {
  declare export class Client {
    constructor(params: Object): Client;

    connect(): Promise<void>;

    query(query: string, value: Array<mixed>): Promise<Object>;

    end(): Promise<void>;
  }
}
