class Turf::Proxy::RequestPlugin::ManualInteraction < Turf::Proxy::RequestPlugin

  def self.run(proxy, proxy_thread)
    terminal_answers = ["d", "c", "f"]
    loop do
      valid_answers = {
        "v" => proc { PrintRequest.run(proxy, proxy_thread) },
        "m" => proc { Mitm.run(proxy, proxy_thread) },
        "d" => proc { throw(:close_connection) },
        # TODO: tests for these were apparently lacking
        "c"=>nil,
        "h"=>nil,
      }
      if proxy_thread.request.method == "CONNECT"
        question = "[m]itm, (c)ontinue, (d)rop, (v)iew, (h)eaders ? "
        valid_answers["m"] = proc { Mitm.run(proxy, proxy_thread) }
        default_answer = "m"
      else
        question = "[f]orward, (c)ontinue, (d)rop, (v)iew, (h)eaders ? "
        valid_answers["f"] = nil
        default_answer = "f"
      end
      answer = nil
      loop do
        answer = proxy.ui.ask(question)
        answer = default_answer if answer.empty?
        break if valid_answers.key? answer
      end
      if valid_answers[answer]
        valid_answers[answer].call
      end
      break if terminal_answers.include? answer
    end
  end

end
