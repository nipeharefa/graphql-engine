import { FastifyRequest } from "fastify"
import { ConfigSchemaResponse } from "./types"

export type Config = {
  tables: String[] | null
}

export const getConfig = (request: FastifyRequest): Config => {
  const configHeader = request.headers["x-hasura-dataconnector-config"];
  const rawConfigJson = Array.isArray(configHeader) ? configHeader[0] : configHeader ?? "{}";
  const config = JSON.parse(rawConfigJson);
  return {
    tables: config.tables ?? null
  }
}

export const configSchema: ConfigSchemaResponse = {
  configSchema: {
    type: "object",
    nullable: false,
    properties: {
      tables: {
        description: "List of tables to make available in the schema and for querying",
        type: "array",
        items: { $ref: "#/otherSchemas/TableName" },
        nullable: true
      }
    }
  },
  otherSchemas: {
    TableName: {
      nullable: false,
      type: "string"
    }
  }
}
