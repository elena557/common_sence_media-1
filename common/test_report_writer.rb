require "time"

module TestReportWriter

  def status(result)
      begin
        result = result.upcase
        if result == "PASS"
          id_value = "statuspass"
        else
          id_value = "statusfail"
        end

        rescue Exception
          id_value = "statusfail"
      end
      id_value
  end


  def html_builder(test_report)

    html_report = <<-EOS
        <html>
    EOS

    html_style = <<-EOS
          <style>
            body {background-color: #FFFFF0; font-family: "VAG Round" ; color : #000080;font-weight:normal;word-break: break-all;}
            #specifications{font-family:Arial,Helvetica,Sans-serif;font-size:13px;width:480px;background:#fff;border-collapse:collapse;text-align:left;margin:20px;border:1px solid #ccc;}
            #specifications th{font-size:14px;font-weight:bold;color:#039;border-bottom:2px solid #6678b1;padding:10px 8px;}
            #specifications td{border-bottom:1px solid #ccc;color:#009;padding:6px 8px;}
            #statuspass{font-family:Arial,Helvetica,Sans-serif;font-size:12px;color:green;font-weight:bold;}
            #statusfail{font-family:Arial,Helvetica,Sans-serif;font-size:12px;color:red;font-weight:bold;}
            #tcs{font-family:Arial,Helvetica,Sans-serif;font-size:13px;background:#fff;width:900px;border-collapse:collapse;text-align:left;margin:20px;border:1px solid #ccc;}
            #tcs th{font-size:14px;font-weight:bold;color:#039;border-bottom:2px solid #6678b1;padding:10px 8px;}
            #tcs td{border-bottom:1px solid #ccc;color:#009;padding:6px 8px;}
            #checkpoint{font-family:Arial,Helvetica,Sans-serif;font-size:13px;background:#fff;width:900px;border-collapse:collapse;text-align:left;margin:20px;border:1px solid #ccc;}
            #checkpoint td{border-bottom:1px solid #ccc;color:#009;padding:6px 8px;}
            #container{margin: 0 30px;background: #fff;border:1px solid #ccc;}
            #header{background: #e8edff;padding: 2px;border-bottom: 2px solid #6678b1;}
            #steps{background: #e8edff;font-weight: bold;}
            #dp{font-weight: bold;}
            #validations{font-weight: bold;}
            #content{clear: left;padding: 10px;}
            #footer{background: #e8edff;text-align: right;padding: 10px;}
          </style>
    EOS

    title = <<-EOS
        <head><title>#{test_report[:title]}</title></head>
        <body>
        <center>
    EOS

    html_report += html_style + title


    test_suite_time_in_secs = Time.parse(test_report[:finish_time].to_s) - Time.parse(test_report[:start_time].to_s)

    report_header = <<-EOS
    <h1><u>#{test_report[:title]}<\/u><\/h1><br\/>
        <h4>Test summary:</h4>
        <table id="specifications" width="900px">
          <tr><td>Test started On: #{test_report[:start_time]}</td></tr>
          <tr><td>Duration: #{test_suite_time_in_secs} secs</td></tr>
          <tr><td>Items tested: #{test_report[:verification].size}</td></tr>
          <tr><td>Test status: <font id=#{status(test_report[:status])}>#{test_report[:status]}</font></td></tr>
        </table>

    EOS

    report_tc_summary = <<-EOS
          <h4>Test results:</h4>
          <table id="tcs">
            <tr>
            <th >#</th>
            <th >URL</th>
            <th >Action</th>
            <th >Result</th>
            </tr>
    EOS

    test_report[:verification].each do |tc_id, tc|
      report_tc_summary += <<-EOS
            <tr>
            <td>#{tc_id}</td><td>#{tc[:page_url]}</td><td>#{tc[:element]}</td><td><font id=#{status(tc[:result])}>#{tc[:result]}</font></td>
            </tr>
      EOS
    end

     report_footer = <<-EOS
          </body>
          </html>
    EOS

    html_report += report_header + report_tc_summary + report_footer

    html_report

  end

end