defmodule LocalOpenAI do
  def create_chat_completion(messages, model) do
    req =
      Req.new(
        base_url: base_url(),
        headers: auth_headers(),
        receive_timeout: receive_timeout(),
        retry: false
      )

    case Req.post(req, url: "/chat/completions", json: %{model: model, messages: messages}) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{} = resp} ->
        {:error, resp}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp config() do
    Application.get_env(:inkfish, :openai, [])
  end

  defp base_url() do
    config()[:base_url] || "http://localhost:8080/v1"
  end

  defp auth_headers() do
    case config()[:api_key] do
      key when is_binary(key) and key != "" -> [{"authorization", "Bearer #{key}"}]
      _ -> []
    end
  end

  defp receive_timeout() do
    config()
    |> Keyword.get(:http_options, [])
    |> Keyword.get(:recv_timeout, 900_000)
  end
end

defmodule LocalGrading do
  def api_base() do
    "http://localhost:4000/api/v1"
  end

  def auth_hdrs() do
    [ 
      {"x-auth", "A271A2AB73869927D323BF74E03DF6DC"}
    ]
  end

  def run() do

    url = api_base() <> "/staff/subs?assignment_id=22"
    resp = Req.get!(url, headers: auth_hdrs())
    
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

    # comments = request_llm_feedback(text)
    comments = [
      %{
        "line" => 9,
        "path" => "starter-lab06/src/main/java/lab06/App.java",
        "text" => "Main method is here.",
        "points" => "0",
      }
    ]

    post_data = %{
      "sub_id" => sub["id"],
      "grade" => %{
        "line_comments" => comments,         
      }
    }

    Req.post!(api_base() <> "/staff/grades", headers: auth_hdrs(), json: post_data)
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
      {"line": 99, "path": "/path/and/file", points: "0",
       "text": "Main method is here."}
    ]
    ```
    """

    messages = [
      %{"role" => "system", "content" => system_msg},
      %{"role" => "user", "content" => prompt}
    ]

    IO.inspect(messages)

    {:ok, resp} = LocalOpenAI.create_chat_completion(messages, "default")

    {:ok, data} =
      hd(resp["choices"])["message"]["content"]
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
