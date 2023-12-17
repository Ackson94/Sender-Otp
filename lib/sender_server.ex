defmodule SendServer do
  use GenServer

  def init(args) do

    IO.puts("Received arguments: #{inspect(args)}")

    max_retries = Keyword.get(args, :max_retries, 5)

    state = %{
      emails: [],
      max_retries: max_retries
    }

    Process.send_after(self(), :retry, 5000)

    {:ok, state}
  end

  # def handle_continue(:fetch_from_database, state) do
  #   # get user from the database
  #   {:noreply, Map.put(state, :users, _users)}
  # end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:send, email}, state) do
    status =
      case Sender.send_email(email) do
        {:ok, "Email sent"} ->
          "sent"

        :error ->
          "Failed"
      end

    emails = [%{email: email, status: status, retries: 0}] ++ state.emails

    {:noreply, Map.put(state, :emails, emails)}
  end

  def handle_info(:retry, state) do
    IO.inspect(state, label: "\n\n\n##########")

    {failed, done} =
      Enum.split_with(state.emails, fn item ->
        item.status == "Failed" && item.retries < state.max_retries
      end)
      IO.inspect(failed, label: "\n\n\n##########failed")

    retried =
      Enum.map(failed, fn item ->
        IO.puts("Retrying email #{item.email}...")

        new_status =
          case Sender.send_email(item.email) do
            {:ok, "Email sent"} ->
              "Sent"

            :error ->
              "Failed"
          end

          IO.inspect(item, label: "\n\n\************item")


        %{email: item.email, status: new_status, retries: item.retries + 1}
      end)

    Process.send_after(self(), :retry, 5000)

    {:noreply, Map.put(state, :emails, retried ++ done)}
  end

  def terminate(reason, _state) do
    IO.puts("Terminating with reason #{reason}")
  end

  GenServer.cast(pid, {:send, "acksonicmutuma@gmail.com"})
end
