defmodule DevTodo.Task do
  @moduledoc false

  defstruct [
    :id,
    :title,
    :status,
    :assignees,
    :pr,
    :attachments,
    :position,
    description: "",
    labels: []
  ]

  @type t :: %__MODULE__{
          id: pos_integer(),
          title: String.t(),
          status: atom(),
          assignees: [String.t()],
          pr: integer() | nil,
          attachments: [String.t()],
          position: non_neg_integer(),
          description: String.t(),
          labels: [String.t()]
        }
end
