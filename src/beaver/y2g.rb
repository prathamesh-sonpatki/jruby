
def match_package(str)
  str.match /package\s.*;/
end

def match_import(str)
  str.match /import\s.*;/
end

def match_class(str)
  str.match /class\s*[A-Z]\w*/
end

def match_java_code(str)
  str.match /[^%^\/].*/
end

def match_token(str)
  str.match /%token\s*<.*>\s*\w*/
end

def match_type(str)
  str.match /%type\s*<.*>\s*(\w*,?\s*)*/
end

def create_token_list(tokens)
  token_list = "";
  tokens.each do |token|
    if not token_list.include? ", " + token + ", "
      token_list += token +", ";
      end
  end
  token_list
end

src = File.new("/home/chaitanya/projects/jruby/src/org/jruby/parser/JavaSignatureParser.y", 'r')
dest = File.new("jruby.grammar", 'w')

input = src.read
#split the input into 3 sections as per convention of yacc file
section1 = (input.match /%{(\n|.)*%}/).to_s
section2 = (input.match /%}(\n|.)*%%(\n|.)*%%/).to_s.gsub! "%}", ""
section3 = (section2.match /%%(\n|.)*%%/).to_s.gsub! "%%", ""
section2.gsub! section3, ""
section2.gsub! "%%", ""
(section3.scan /\/\/.+/).each do |arg|
  section3[arg] = ''
end
(section3.scan /\/\*[.\s]*\*\//).each do |arg|
  section3[arg] = ''
end
 
#comments from section1
comments = section1.match /\/\*(.|\n)*\*\//
section1.gsub! comments.to_s, ""
section1.gsub! "%{", ""
section1.gsub! "%}", ""
section1 = section1.split "\n"
section2 = section2.split "\n"
section3 = section3.split
count = 0


#section3 = section3.split
section3.delete ""
embed = ""
tokens = []
types = {}

#process section1
section1.each do |line|

  if result = match_package(line)
    result = result.to_s.split
    result[1].gsub! ";" , '";'
    dest.write ("%" + result[0] + ' "' + result[1])
  elsif result = match_import(line)
    result = result.to_s.split
    result[1].gsub! ";" , '";'
    dest.write("\n%" + result[0] + ' "' + result[1] )
  elsif result = match_java_code(line)
    embed += result.to_s + "\n"
  end
  if result = match_class(line)
    result = result.to_s.split
    dest.write("\n\n%" + result[0] + ' "' + result[1] + '";')
  end
end

embed.gsub! (embed.scan /.*{/)[0].to_s, ''
embed.gsub! (embed.scan /\n\n/)[0].to_s, '' 
dest.write "\n\n%embed{:\n" + embed + "\n:};"

#process section2
section2.each do |line|
  if result = match_token(line)
    result =  result.to_s
    result.gsub! "<", ""
    result.gsub! ">", ""
    result = result.split
    tokens << result[2]
    if types[result[1].to_sym]
      types[result[1].to_sym] += [ result[2].to_s ]
    else
      types[result[1].to_sym] = [ result[2].to_s ]
    end
  elsif result = match_type(line)
    result = result.to_s
    result.gsub! "<", ""
    result.gsub! "<", ""
    result.gsub! ">", ""
    result.gsub! ",", ""
    result = result.split
    if types[result[1].to_sym]
      types[result[1].to_sym] += [result[2].to_s]
    else
      types[result[1].to_sym] = [result[2] ]
    end
  end
end

dest.write "\n\n%terminals "
dest.write " " + create_token_list(tokens)[0..-3]+";"

types.each_key do |type|
  dest.write "\n\n%typeof " + create_token_list(types[type])[0..-3] + " = " + '"' +  type.to_s  + '"' + ";"
end

#process section3

@state = 'lhs'
@count = 1
@loop = 0
@index = 0
@paren = 0
@return = false
section3.each do |token|
  if @index == 0
    dest.write "\n%goal " + token + ";\n"
  end
  if token.include? "comment#"
    dest.write "\n" + section3_comments[token[-1].to_i] + "\n"
  elsif @state == 'lhs'
    if token == ":"
      dest.write " = "
      @state = 'rhs_initial'
    elsif (token.scan /\w+:/) != []
      dest.write token[0, token.length - 1] + '='
      @state = 'rhs_initial'
    elsif token =~ /\w+/
      dest.write "\n"+token
    end
  elsif @state == 'rhs_initial'
    if token == "{"
      @state ="javacode_start"
      @count = 1
      dest.write  "\n"+ token + ":\n"
    elsif token == "|"
      dest.write token + "\n "
    elsif (token.scan /\w+/) != [] and (section3[@index + 1].scan /\w+/) != [] and section3[@index + 2] == ":"
      @count = 1
    elsif token =~ /\w+/ and section3[ @index + 1] == ":"
      dest.write ";\n"
      dest.write token+" "
      @state = 'lhs'
    elsif (token.scan /\w+/) != []
      unless token.include? '\'' and  token.include? '"' 
        #p token
        dest.write token+".arg#{@count} "
      end
      @count = @count + 1
     end
  elsif @state == "javacode_start"
    if token == "{"
      dest.write "\n" + token +"\n"
      @loop = @loop + 1
    elsif token == "}" and @loop !=0
      dest.write "\n" + token + "\n"
      @loop = @loop - 1
    elsif token == "}"
      if @return == false
        dest.write "\n return new Symbol(arg1);"
      else
        @return = false
      end
      if section3[@index + 2] == ":" or @index == (section3.length - 1) or ((section3[@index + 2].scan(/\w*/)) != [] and section3[@index+1] == '|')
        dest.write "\n:" + token + "\n"
      else
       # dest.write "\n" + token + "\n"
      end
      @state = "rhs_initial"
      @count = 1
    elsif token == "$$"
      @return = true
      dest.write "\n return new Symbol("
    elsif (token.scan /.*\$\d.*/) != []
      while (token.scan /.*\$\d.*/) != [] 
        argument = (token.scan /\$\d/).to_s
        token[argument[2] + argument[3]] = "arg" + argument[3]
        if  token[-1] == ";" and @return_state == 'return_rhs'
          token[-1] = ');'
          @return_state = ''
        end
        end
        dest.write token + " "
      
    elsif (token.scan /.*\$<.*>\d/) != []
      while  (token.scan /.*\$<.*>\d/) != []
        token.gsub! (token.match /<.*>/)[0] , ""
       
        argument = (token.scan /\$\d/).to_s
        token[argument[2] + argument[3]] = "arg" + argument[3]
        if token[-1] == ";" and @return_state == 'return_rhs'
          token[-1] = ');'
          @return_state = ''
        end
        end
        dest.write token + " "
      
      elsif token == "if" || token == "else"
      dest.write "\n" + token
    elsif token == "=" and @return == true
      dest.write ""
      @return_state = 'return_rhs'
    else
       if token[-1] == ";" and @return_state == 'return_rhs' 
        token[-1] = ');'
        @return_state = ''
      end
            dest.write token + " "
    end
  end
  @index = @index + 1
end

dest.write "\n;"
#wrap up the process
src.close
dest.close


