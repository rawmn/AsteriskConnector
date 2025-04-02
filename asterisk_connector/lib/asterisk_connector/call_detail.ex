defmodule CallDetail do
  defstruct call_id: nil,
            account_code: nil,
            caller: %{
              name: nil,
              number: nil,
              channel: nil
            },
            callee: %{
              name: nil,
              number: nil,
              channel: nil
            },
            timestamps: %{
              start: nil,
              answer: nil,
              end: nil,
              duration_call: nil,
              duration_answer: nil,
              duration_ring: nil
            },
            exten: nil,
            context: nil,
            status: nil,
            last_channel_state: nil,
            who_hangup: nil,
            quality_metrics: %{
              max_rtt: 0.0,
              max_loss: 0,
              r_factor: nil,
              quality: nil
            }

  use GenServer

  def start(name) do
    GenServer.start_link(__MODULE__, %CallDetail{}, name: via_tuple(name))
  end

  defp via_tuple(name) do
    {:via, :gproc, {:n, :l, {:call, name}}}
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_call(:get, _, state) do
    {:reply, state, state}
  end

  def handle_call(:get_start_time, _, state) do
    {:reply, state.timestamps.start, state}
  end

  def handle_call(:get_answer_time, _, state) do
    {:reply, state.timestamps.answer, state}
  end

  def handle_call(:get_metrics, _, state) do
    {:reply, state.quality_metrics, state}
  end

  def handle_cast({:newchannel, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{
        state
        | call_id: data.call_id,
          account_code: data.account_code,
          caller: data.caller,
          exten: data.exten,
          context: data.context,
          last_channel_state: data.last_channel_state,
          timestamps: %{state.timestamps | start: data.start_time}
      }
    }
  end

  def handle_cast({:newchannel_callee, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{state | callee: data.callee, last_channel_state: data.last_channel_state}
    }
  end

  def handle_cast({:bridgeenter, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{
        state
        | timestamps: %{
            state.timestamps
            | answer: data.answer_time,
              duration_ring: data.duration_ring
          },
          last_channel_state: data.last_channel_state
      }
    }
  end

  def handle_cast({:who_hangup_put, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{
        state
        | who_hangup: data.who_hangup,
          last_channel_state: data.last_channel_state
      }
    }
  end

  def handle_cast({:set_status, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{state | status: data}
    }
  end

  def handle_cast({:hangup, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{
        state
        | last_channel_state: data.last_channel_state,
          timestamps: %{
            state.timestamps
            | end: data.end_time,
              duration_answer: data.duration_answer,
              duration_call: data.duration_call
          }
      }
    }
  end

  def handle_cast({:rtcpreceived, data}, state = %CallDetail{}) do
    {
      :noreply,
      %CallDetail{state | quality_metrics: data}
    }
  end
end
