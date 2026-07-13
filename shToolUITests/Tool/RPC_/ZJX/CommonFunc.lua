local CommonFunc = {}


function CommonFunc.fileRead(path)
  if not path then return nil end
  local file = io.open(path, "r")
  if file then
    data = file:read("*all")
    file:close()
    return data
  end
  return ""
end


function CommonFunc.writeToFile(path, data, mode)
    local fileMode = mode or "w"
    local file, err = io.open(path, fileMode)
    if file then
        local success, writeErr = file:write(data)
        file:close()
        return success, writeErr
    end
    return nil, err
end

function CommonFunc.get_users_name()
    os.execute("rm /tmp/zjx/1.txt")
    os.execute("mkdir -p /tmp/zjx | touch /tmp/zjx/1.txt | echo $(Users)  >> /tmp/zjx/1.txt")
    users_name= CommonFunc.fileRead("/tmp/zjx/1.txt")
    return users_name
end

function CommonFunc.show_message(title,message)
    local title = title or "错误"
    local message = message or "ERROR"
    local info = string.format('osascript -e \'display alert "%s" message "%s" as critical\'',title,message)
    os.execute("mkdir -p /tmp/zjx;touch /tmp/zjx/show_message.sh")
    os.execute("rm /tmp/zjx/show_message.sh")
    CommonFunc.writeToFile("/tmp/zjx/show_message.sh",info)
    os.execute("sh /tmp/zjx/show_message.sh")
    return info
end

-- show_message(nil,"123131231221")
return CommonFunc