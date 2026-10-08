defmodule Room.Http.Openapi do
  @moduledoc "Minimal OpenAPI map for Custom GPT Actions / Grok tools."

  def spec do
    %{
      openapi: "3.1.0",
      info: %{
        title: "Mazel v0",
        version: "0.1.0",
        description: "Same tools as the Mazel MCP adapter."
      },
      paths: %{
        "/v0/find" => %{
          get: %{operationId: "mazel_find"},
          post: %{
            operationId: "mazel_find_post",
            requestBody: json_body(%{query: %{type: "string"}}, ["query"])
          }
        },
        "/v0/resolve" => %{
          post: %{
            operationId: "mazel_resolve",
            requestBody: json_body(%{handle: %{type: "string"}}, ["handle"])
          }
        },
        "/v0/wing" => %{
          post: %{
            operationId: "mazel_wing",
            requestBody: json_body(%{text: %{type: "string"}, from: %{type: "string"}}, ["text"])
          }
        },
        "/v0/need" => %{
          post: %{
            operationId: "mazel_need",
            requestBody:
              json_body(%{text: %{type: "string"}, ttl_hours: %{type: "integer"}}, ["text"])
          }
        },
        "/v0/open" => %{
          post: %{
            operationId: "mazel_open",
            requestBody:
              json_body(
                %{
                  text: %{type: "string"},
                  ttl_hours: %{type: "integer"},
                  handle: %{type: "string"}
                },
                ["text"]
              )
          }
        },
        "/v0/rooms/{id}/badge" => %{post: %{operationId: "mazel_badge"}},
        "/v0/rooms/{id}/consent" => %{post: %{operationId: "mazel_consent"}},
        "/v0/rooms/{id}/commit" => %{post: %{operationId: "mazel_commit"}},
        "/v0/rooms/{id}/warm_packet" => %{get: %{operationId: "mazel_warm_packet"}}
      }
    }
  end

  defp json_body(properties, required) do
    %{
      required: true,
      content: %{
        "application/json" => %{
          schema: %{type: "object", properties: properties, required: required}
        }
      }
    }
  end
end
