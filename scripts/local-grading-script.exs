defmodule LocalGrading do
  alias ExOpenAI.Components.ChatCompletionRequestSystemMessage, as: SystemMsg
  alias ExOpenAI.Components.ChatCompletionRequestUserMessage, as: UserMsg
  #alias ExOpenAI.Components.ChatCompletionRequestAssistantMessage, as: AstMsg

  def run() do
    hdrs = [
      {"x-auth", "A271A2AB73869927D323BF74E03DF6DC"}
    ]

    resp = Req.get!("http://localhost:4000/api/v1/staff/subs?assignment_id=22", headers: hdrs)
    
    sub = hd(resp.body["data"])
    task = Task.async(fn -> grade_sub(sub) end)
    Task.await(task, 900_000)
  end

  def grade_sub(sub) do
    Process.flag(:max_heap_size, 20_000_000)

    name = sub["reg"]["user"]["name"]
    url = sub["upload"]
    IO.puts("#{name}: #{url}")

    resp = Req.get!(url)
    text = flatten_for_llm(resp.body)

    IO.puts(text)

    request_llm_feedback(text)
  end

  def flatten_for_llm(files) do
    files
    |> Enum.map(fn {name, data} ->
      {to_string(name), data}
    end)
    |> Enum.filter(fn {name, _data} ->
      !String.match?(name, ~r{/\.}) 
    end)
    |> Enum.map(fn {name, data} ->
      """

      #{name}
      ```
      #{data}
      ```

      """
    end)
    |> Enum.join()
  end

  def request_llm_feedback(text) do
    system_msg = """
    You are a teaching assistant for a college programming course. 
    Analyze the provided student code according to the instructions and 
    provide output in the requested format.
    """

    prompt = """
    Here is the code submitted by the student:

    #{text}

    Where is the main method? Provide the file name and line number.

    Provide the answer as json data formatted like this:
    
    ```json
    [
      {"path": "/path/and/file", "line": 99, "comment": "Main method is here."}
    ]
    ```
    """

    messages = [
      %SystemMsg{role: :system, content: system_msg},
      %UserMsg{role: :user, content: prompt},
    ]

    IO.inspect(messages)

    {:ok, resp} = ExOpenAI.Chat.create_chat_completion(messages, "default")

    {:ok, data} = hd(resp.choices)[:message][:content]
    |> extract_json_response()

    IO.inspect({:data, data})
  end

  def extract_json_response(text) do
    pat = ~r/```json\n(.*)```\s*$/s
    [_, json] = Regex.run(pat, text)
    Jason.decode(json)
  end
end

LocalGrading.run()
