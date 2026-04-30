class HtaccessRedirects
  def execute(site)
    htaccess = File.join(site.dir, '.htaccess')
    raise "#{htaccess} not found" unless File.exist?(htaccess)

    rules = parse(htaccess)
    existing_paths = build_page_index(site)

    rules.each do |rule|
      if rule[:wildcard]
        expand_wildcard(site, rule, existing_paths)
      else
        add_redirect(site, rule[:from], rule[:to], existing_paths)
      end
    end
  end

  private

  def add_redirect(site, from, to, existing_paths)
    if from.end_with?('.html')
      output_path = from
    elsif from.end_with?('/')
      output_path = "#{from}index.html"
    else
      output_path = "#{from}/index.html"
    end

    # Remove any existing page at this path (redirect overrides static content)
    site.pages.reject! { |p| p.output_path == output_path }
    existing_paths.delete(output_path)

    page = site.engine.load_page(File.join(File.dirname(__FILE__), 'redirect_template.html.haml'))
    page.output_path = output_path
    page.redirect_target = to
    site.pages << page
  end

  def expand_wildcard(site, rule, existing_paths)
    from_prefix = rule[:from]
    to_prefix = rule[:to]

    # Resolve "current" in target by following the chain
    resolved_to = resolve_target_prefix(to_prefix)

    # Find all existing pages under the resolved target prefix
    target_prefix_with_slash = normalized_prefix(resolved_to)

    matching_paths = existing_paths.keys.select { |p| p.start_with?(target_prefix_with_slash) }

    if matching_paths.empty?
      # No pages found — just create a redirect at the root
      add_redirect(site, from_prefix, "/#{to_prefix}", existing_paths)
      return
    end

    matching_paths.each do |target_path|
      suffix = target_path.sub(target_prefix_with_slash, '')
      source_path = "#{normalized_prefix(from_prefix)}#{suffix}"
      target_url = "/#{resolved_to}/#{suffix}".gsub('//', '/')
      # Convert file paths to browsable URLs
      target_url = target_url.sub(/index\.html$/, '').sub(/\.html$/, '/')
      add_redirect(site, source_path, target_url, existing_paths)
    end

    # Also create a redirect at the root of the prefix
    add_redirect(site, from_prefix, "/#{to_prefix}", existing_paths)
  end

  def resolve_target_prefix(target)
    # Resolve /documentation/current/X to /documentation/1.3/X
    target.sub('documentation/current', 'documentation/1.3')
  end

  def normalized_prefix(prefix)
    prefix.end_with?('/') ? prefix : "#{prefix}/"
  end

  def build_page_index(site)
    index = {}
    site.pages.each do |page|
      index[page.output_path] = page
    end
    index
  end

  def parse(path)
    rules = []
    active = false

    File.readlines(path).each_with_index do |raw_line, idx|
      lineno = idx + 1
      line = raw_line.strip

      next if line.empty? || line.start_with?('#')

      if line.start_with?('RewriteCond')
        active = true
        next
      end

      if !line.start_with?('RewriteRule')
        handle_directive(line, lineno)
        next
      end

      unless active
        raise "Line #{lineno}: RewriteRule without preceding RewriteCond: #{line}"
      end

      rule = parse_rewrite_rule(line, lineno)
      rules << rule
    end

    rules
  end

  KNOWN_DIRECTIVES = %w[Options RewriteEngine IndexIgnore DirectoryIndex ErrorDocument]

  def handle_directive(line, lineno)
    return if KNOWN_DIRECTIVES.any? { |d| line.start_with?(d) }
    raise "Line #{lineno}: unrecognized directive: #{line}"
  end

  def parse_rewrite_rule(line, lineno)
    match = line.match(/^RewriteRule\s+(\S+)\s+(".*?"|\S+)(.*)$/)
    raise "Line #{lineno}: cannot parse RewriteRule: #{line}" unless match

    pattern = match[1]
    target = match[2]

    from, wildcard = pattern_to_path(pattern, lineno)
    to = unescape_target(target)

    { from: from, to: to, wildcard: wildcard, lineno: lineno }
  end

  def pattern_to_path(pattern, lineno)
    path = pattern
      .sub(/^\^/, '')
      .sub(/\$$/, '')

    if path.end_with?('(.*)')
      [path.sub('(.*)', ''), true]
    elsif path =~ /[\\()\[\]+*?{}|]/
      raise "Line #{lineno}: unsupported regex pattern: #{pattern}" \
            "\nHint: comment out or remove this rule if the redirect is no longer needed"
    else
      [path, false]
    end
  end

  def unescape_target(target)
    target
      .gsub(/^"|"$/, '')
      .gsub('\\:', ':')
      .gsub('\\/', '/')
      .gsub('\\.', '.')
      .gsub(/\s*\[.*\]\s*$/, '')
      .sub(/\$1$/, '')
  end
end
