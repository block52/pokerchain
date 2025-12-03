import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, ResponseType } from "axios";
import { QueryParamsResponse } from "./types/pokerchain/poker/v1/query";
import { QueryGameResponse } from "./types/pokerchain/poker/v1/query";
import { QueryListGamesResponse } from "./types/pokerchain/poker/v1/query";
import { QueryPlayerGamesResponse } from "./types/pokerchain/poker/v1/query";
import { QueryLegalActionsResponse } from "./types/pokerchain/poker/v1/query";
import { QueryGameStateResponse } from "./types/pokerchain/poker/v1/query";
import { QueryGameStatePublicResponse } from "./types/pokerchain/poker/v1/query";
import { QueryIsTxProcessedResponse } from "./types/pokerchain/poker/v1/query";
import { QueryGetWithdrawalRequestResponse } from "./types/pokerchain/poker/v1/query";
import { QueryListWithdrawalRequestsResponse } from "./types/pokerchain/poker/v1/query";

import { QueryParamsRequest } from "./types/pokerchain/poker/v1/query";
import { QueryGameRequest } from "./types/pokerchain/poker/v1/query";
import { QueryListGamesRequest } from "./types/pokerchain/poker/v1/query";
import { QueryPlayerGamesRequest } from "./types/pokerchain/poker/v1/query";
import { QueryLegalActionsRequest } from "./types/pokerchain/poker/v1/query";
import { QueryGameStateRequest } from "./types/pokerchain/poker/v1/query";
import { QueryGameStatePublicRequest } from "./types/pokerchain/poker/v1/query";
import { QueryIsTxProcessedRequest } from "./types/pokerchain/poker/v1/query";
import { QueryGetWithdrawalRequestRequest } from "./types/pokerchain/poker/v1/query";
import { QueryListWithdrawalRequestsRequest } from "./types/pokerchain/poker/v1/query";


import type {SnakeCasedPropertiesDeep} from 'type-fest';

export type QueryParamsType = Record<string | number, any>;

export type FlattenObject<TValue> = CollapseEntries<CreateObjectEntries<TValue, TValue>>;

type Entry = { key: string; value: unknown };
type EmptyEntry<TValue> = { key: ''; value: TValue };
type ExcludedTypes = Date | Set<unknown> | Map<unknown, unknown>;
type ArrayEncoder = `[${bigint}]`;

type EscapeArrayKey<TKey extends string> = TKey extends `${infer TKeyBefore}.${ArrayEncoder}${infer TKeyAfter}`
  ? EscapeArrayKey<`${TKeyBefore}${ArrayEncoder}${TKeyAfter}`>
  : TKey;

// Transforms entries to one flattened type
type CollapseEntries<TEntry extends Entry> = {
  [E in TEntry as EscapeArrayKey<E['key']>]: E['value'];
};

// Transforms array type to object
type CreateArrayEntry<TValue, TValueInitial> = OmitItself<
  TValue extends unknown[] ? { [k: ArrayEncoder]: TValue[number] } : TValue,
  TValueInitial
>;

// Omit the type that references itself
type OmitItself<TValue, TValueInitial> = TValue extends TValueInitial
  ? EmptyEntry<TValue>
  : OmitExcludedTypes<TValue, TValueInitial>;

// Omit the type that is listed in ExcludedTypes union
type OmitExcludedTypes<TValue, TValueInitial> = TValue extends ExcludedTypes
  ? EmptyEntry<TValue>
  : CreateObjectEntries<TValue, TValueInitial>;

type CreateObjectEntries<TValue, TValueInitial> = TValue extends object
  ? {
      // Checks that Key is of type string
      [TKey in keyof TValue]-?: TKey extends string
        ? // Nested key can be an object, run recursively to the bottom
          CreateArrayEntry<TValue[TKey], TValueInitial> extends infer TNestedValue
          ? TNestedValue extends Entry
            ? TNestedValue['key'] extends ''
              ? {
                  key: TKey;
                  value: TNestedValue['value'];
                }
              :
                  | {
                      key: `${TKey}.${TNestedValue['key']}`;
                      value: TNestedValue['value'];
                    }
                  | {
                      key: TKey;
                      value: TValue[TKey];
                    }
            : never
          : never
        : never;
    }[keyof TValue] // Builds entry for each key
  : EmptyEntry<TValue>;

export type ChangeProtoToJSPrimitives<T extends object> = {
  [key in keyof T]: T[key] extends Uint8Array | Date ? string :  T[key] extends object ? ChangeProtoToJSPrimitives<T[key]>: T[key];
  // ^^^^ This line is used to convert Uint8Array to string, if you want to keep Uint8Array as is, you can remove this line
}

export interface FullRequestParams extends Omit<AxiosRequestConfig, "data" | "params" | "url" | "responseType"> {
  /** set parameter to `true` for call `securityWorker` for this request */
  secure?: boolean;
  /** request path */
  path: string;
  /** content type of request body */
  type?: ContentType;
  /** query params */
  query?: QueryParamsType;
  /** format of response (i.e. response.json() -> format: "json") */
  format?: ResponseType;
  /** request body */
  body?: unknown;
}

export type RequestParams = Omit<FullRequestParams, "body" | "method" | "query" | "path">;

export interface ApiConfig<SecurityDataType = unknown> extends Omit<AxiosRequestConfig, "data" | "cancelToken"> {
  securityWorker?: (
    securityData: SecurityDataType | null,
  ) => Promise<AxiosRequestConfig | void> | AxiosRequestConfig | void;
  secure?: boolean;
  format?: ResponseType;
}

export enum ContentType {
  Json = "application/json",
  FormData = "multipart/form-data",
  UrlEncoded = "application/x-www-form-urlencoded",
}

export class HttpClient<SecurityDataType = unknown> {
  public instance: AxiosInstance;
  private securityData: SecurityDataType | null = null;
  private securityWorker?: ApiConfig<SecurityDataType>["securityWorker"];
  private secure?: boolean;
  private format?: ResponseType;

  constructor({ securityWorker, secure, format, ...axiosConfig }: ApiConfig<SecurityDataType> = {}) {
    this.instance = axios.create({ ...axiosConfig, baseURL: axiosConfig.baseURL || "" });
    this.secure = secure;
    this.format = format;
    this.securityWorker = securityWorker;
  }

  public setSecurityData = (data: SecurityDataType | null) => {
    this.securityData = data;
  };

  private mergeRequestParams(params1: AxiosRequestConfig, params2?: AxiosRequestConfig): AxiosRequestConfig {
    return {
      ...this.instance.defaults,
      ...params1,
      ...(params2 || {}),
      headers: {
        ...(this.instance.defaults.headers ),
        ...(params1.headers || {}),
        ...((params2 && params2.headers) || {}),
      },
    } as AxiosRequestConfig;
  }

  private createFormData(input: Record<string, unknown>): FormData {
    return Object.keys(input || {}).reduce((formData, key) => {
      const property = input[key];
      formData.append(
        key,
        property instanceof Blob
          ? property
          : typeof property === "object" && property !== null
          ? JSON.stringify(property)
          : `${property}`,
      );
      return formData;
    }, new FormData());
  }

  public request = async <T = any>({
    secure,
    path,
    type,
    query,
    format,
    body,
    ...params
  }: FullRequestParams): Promise<AxiosResponse<T>> => {
    const secureParams =
      ((typeof secure === "boolean" ? secure : this.secure) &&
        this.securityWorker &&
        (await this.securityWorker(this.securityData))) ||
      {};
    const requestParams = this.mergeRequestParams(params, secureParams);
    const responseFormat = (format && this.format) || void 0;

    if (type === ContentType.FormData && body && body !== null && typeof body === "object") {
      requestParams.headers.common = { Accept: "*/*" };
      requestParams.headers.post = {};
      requestParams.headers.put = {};

      body = this.createFormData(body as Record<string, unknown>);
    }

    return this.instance.request({
      ...requestParams,
      headers: {
        ...(type && type !== ContentType.FormData ? { "Content-Type": type } : {}),
        ...(requestParams.headers || {}),
      },
      params: query,
      responseType: responseFormat,
      data: body,
      url: path,
    });
  };
}

/**
 * @title pokerchain.poker.v1
 */
export class Api<SecurityDataType extends unknown> extends HttpClient<SecurityDataType> {
  /**
   * QueryParams
   *
   * @tags Query
   * @name queryParams
   * @request GET:/block52/pokerchain/poker/v1/params
   */
  queryParams = (
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryParamsResponse>>>({
      path: `/block52/pokerchain/poker/v1/params`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryGame
   *
   * @tags Query
   * @name queryGame
   * @request GET:/block52/pokerchain/poker/v1/game/{game_id}
   */
  queryGame = (game_id: string,
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryGameResponse>>>({
      path: `/block52/pokerchain/poker/v1/game/${game_id}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryListGames
   *
   * @tags Query
   * @name queryListGames
   * @request GET:/block52/pokerchain/poker/v1/list_games
   */
  queryListGames = (
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryListGamesResponse>>>({
      path: `/block52/pokerchain/poker/v1/list_games`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryPlayerGames
   *
   * @tags Query
   * @name queryPlayerGames
   * @request GET:/block52/pokerchain/poker/v1/player_games/{player_address}
   */
  queryPlayerGames = (player_address: string,
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryPlayerGamesResponse>>>({
      path: `/block52/pokerchain/poker/v1/player_games/${player_address}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryLegalActions
   *
   * @tags Query
   * @name queryLegalActions
   * @request GET:/block52/pokerchain/poker/v1/legal_actions/{game_id}/{player_address}
   */
  queryLegalActions = (game_id: string, player_address: string,
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryLegalActionsResponse>>>({
      path: `/block52/pokerchain/poker/v1/legal_actions/${game_id}/${player_address}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryGameState
   *
   * @tags Query
   * @name queryGameState
   * @request GET:/block52/pokerchain/poker/v1/game_state/{game_id}
   */
  queryGameState = (game_id: string,
    query?: Omit<FlattenObject<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryGameStateRequest>>>,"game_id">,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryGameStateResponse>>>({
      path: `/block52/pokerchain/poker/v1/game_state/${game_id}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryGameStatePublic
   *
   * @tags Query
   * @name queryGameStatePublic
   * @request GET:/block52/pokerchain/poker/v1/game_state_public/{game_id}
   */
  queryGameStatePublic = (game_id: string,
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryGameStatePublicResponse>>>({
      path: `/block52/pokerchain/poker/v1/game_state_public/${game_id}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryIsTxProcessed
   *
   * @tags Query
   * @name queryIsTxProcessed
   * @request GET:/block52/pokerchain/poker/v1/is_tx_processed/{eth_tx_hash}
   */
  queryIsTxProcessed = (eth_tx_hash: string,
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryIsTxProcessedResponse>>>({
      path: `/block52/pokerchain/poker/v1/is_tx_processed/${eth_tx_hash}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryGetWithdrawalRequest
   *
   * @tags Query
   * @name queryGetWithdrawalRequest
   * @request GET:/block52/pokerchain/poker/v1/withdrawal_request/{nonce}
   */
  queryGetWithdrawalRequest = (nonce: string,
    query?: Record<string, any>,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryGetWithdrawalRequestResponse>>>({
      path: `/block52/pokerchain/poker/v1/withdrawal_request/${nonce}`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
  /**
   * QueryListWithdrawalRequests
   *
   * @tags Query
   * @name queryListWithdrawalRequests
   * @request GET:/block52/pokerchain/poker/v1/withdrawal_requests
   */
  queryListWithdrawalRequests = (
    query?: Omit<FlattenObject<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryListWithdrawalRequestsRequest>>>,"">,
    params: RequestParams = {},
  ) =>
    this.request<SnakeCasedPropertiesDeep<ChangeProtoToJSPrimitives<QueryListWithdrawalRequestsResponse>>>({
      path: `/block52/pokerchain/poker/v1/withdrawal_requests`,
      method: "GET",
      query: query,
      format: "json",
      ...params,
    });
  
}