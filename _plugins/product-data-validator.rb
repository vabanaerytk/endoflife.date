# Verify product data by performing some validation before and after products are enriched.
# Note that the site build is stopped if the validation fails.
#
# The validation done before enrichment is the validation of the properties set by the users.
#
# The validation done after enrichment is mainly the validation of URLs, because most of the URLs
# are generated by the changelogTemplate. Note that this validation is not done by default because
# it takes a lot of time. You can activate it by setting the MUST_CHECK_URLS environment variable to
# true before building the site.

require 'jekyll'
require 'open-uri'

module EndOfLifeHooks
  VERSION = '1.0.0'
  TOPIC = 'Product Validator:'
  VALID_CATEGORIES = %w[app db device framework lang library os server-app service standard]

  IGNORED_URL_PREFIXES = {
    'https://www.nokia.com': 'always return a Net::ReadTimeout',
  }
  SUPPRESSED_BECAUSE_403 = 'may trigger a 403 Forbidden or a redirection forbidden'
  SUPPRESSED_BECAUSE_502 = 'may return a 502 Bad Gateway'
  SUPPRESSED_BECAUSE_503 = 'may return a 503 Service Unavailable'
  SUPPRESSED_BECAUSE_TIMEOUT = 'may trigger an open or read timeout'
  SUPPRESSED_BECAUSE_EOF = 'may return an "unexpected eof while reading" error'
  SUPPRESSED_BECAUSE_CERT = 'site have an invalid certificate'
  SUPPRESSED_BECAUSE_UNAVAILABLE = 'site is temporary unavailable'
  SUPPRESSED_URL_PREFIXES = {
    'https://ark.intel.com': SUPPRESSED_BECAUSE_403,
    'https://azure.microsoft.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://business.adobe.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://blogs.oracle.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://codex.wordpress.org/Supported_Versions': SUPPRESSED_BECAUSE_EOF,
    'https://dev.mysql.com': SUPPRESSED_BECAUSE_403,
    'https://docs.clamav.net': SUPPRESSED_BECAUSE_403,
    'https://docs-prv.pcisecuritystandards.org': SUPPRESSED_BECAUSE_403,
    'https://dragonwell-jdk.io/': SUPPRESSED_BECAUSE_UNAVAILABLE,
    'https://euro-linux.com': SUPPRESSED_BECAUSE_403,
    'https://github.com/angular/angular.js/blob/v1.6.10/CHANGELOG.md': SUPPRESSED_BECAUSE_502,
    'https://github.com/ansible-community/ansible-build-data/blob/main/4/CHANGELOG-v4.rst': SUPPRESSED_BECAUSE_502,
    'https://github.com/nodejs/node/blob/main/doc/changelogs/': SUPPRESSED_BECAUSE_502,
    'https://make.wordpress.org': SUPPRESSED_BECAUSE_EOF,
    'https://mirrors.slackware.com': SUPPRESSED_BECAUSE_403,
    'https://opensource.org/licenses/osl-3.0.php': SUPPRESSED_BECAUSE_403,
    'https://reload4j.qos.ch/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://support.azul.com': SUPPRESSED_BECAUSE_403,
    'https://support.fairphone.com': SUPPRESSED_BECAUSE_403,
    'https://web.archive.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://wiki.debian.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://wordpress.org': SUPPRESSED_BECAUSE_EOF,
    'https://www.amazon.com/gp/help/customer/display.html': SUPPRESSED_BECAUSE_403,
    'https://www.amazon.com/Kindle10Notes': SUPPRESSED_BECAUSE_503,
    'https://www.amazon.com/Voyage7Notes': SUPPRESSED_BECAUSE_503,
    'https://www.atlassian.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.adobe.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.citrix.com/products/citrix-virtual-apps-and-desktops/': SUPPRESSED_BECAUSE_403,
    'https://www.clamav.net': SUPPRESSED_BECAUSE_403,
    'https://www.drupal.org/': SUPPRESSED_BECAUSE_403,
    'https://www.intel.com': SUPPRESSED_BECAUSE_403,
    'https://www.java.com/releases/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.microfocus.com/documentation/visual-cobol/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.microsoft.com/download/internet-explorer.aspx': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.microsoft.com/edge': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.microsoft.com/windows': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.mysql.com': SUPPRESSED_BECAUSE_403,
    'https://xenserver.org/': SUPPRESSED_BECAUSE_CERT,
  }
  USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0'
  URL_CHECK_OPEN_TIMEOUT = 3
  URL_CHECK_TIMEOUT = 10

  # Global error count
  @@error_count = 0

  def self.increase_error_count
    @@error_count += 1
  end

  def self.error_count
    @@error_count
  end

  def self.validate(product)
    start = Time.now
    Jekyll.logger.debug TOPIC, "Validating '#{product.name}'..."

    error_if = Validator.new(product, product.data)
    error_if.is_not_a_string('title')
    error_if.is_not_in('category', EndOfLifeHooks::VALID_CATEGORIES)
    error_if.does_not_match('tags', /^[a-z0-9\-]+( [a-z0-9\-]+)*$/) if product.data.has_key?('tags')
    error_if.does_not_match('permalink', /^\/[a-z0-9-]+$/)
    error_if.does_not_match('alternate_urls', /^\/[a-z0-9\-_]+$/)
    error_if.is_not_a_string('versionCommand') if product.data.has_key?('versionCommand')
    error_if.is_not_an_url('releasePolicyLink') if product.data.has_key?('releasePolicyLink')
    error_if.is_not_an_url('releaseImage') if product.data.has_key?('releaseImage')
    error_if.is_not_an_url('changelogTemplate') if product.data.has_key?('changelogTemplate')
    error_if.is_not_a_string('releaseLabel') if product.data.has_key?('releaseLabel')
    error_if.is_not_a_string('LTSLabel')
    error_if.is_not_a_boolean_nor_a_string('eolColumn')
    error_if.is_not_a_number('eolWarnThreshold')
    error_if.is_not_a_boolean_nor_a_string('activeSupportColumn')
    error_if.is_not_a_number('activeSupportWarnThreshold')
    error_if.is_not_a_boolean_nor_a_string('releaseColumn')
    error_if.is_not_a_boolean_nor_a_string('releaseDateColumn')
    error_if.is_not_a_boolean_nor_a_string('discontinuedColumn')
    error_if.is_not_a_number('discontinuedWarnThreshold')
    error_if.is_not_a_boolean_nor_a_string('extendedSupportColumn')
    error_if.is_not_a_number('extendedSupportWarnThreshold')
    error_if.is_not_an_array('auto')
    error_if.is_not_an_array('identifiers')
    error_if.is_not_an_array('releases')

    product.data['releases'].each { |release|
      error_if = Validator.new(product, release)
      error_if.is_not_a_string('releaseCycle')
      error_if.is_not_a_string('releaseLabel') if release.has_key?('releaseLabel')
      error_if.is_not_a_string('codename') if release.has_key?('codename')
      error_if.is_not_a_date('releaseDate') if product.data['releaseDateColumn']
      error_if.too_far_in_future('releaseDate') if product.data['releaseDateColumn']
      error_if.is_not_a_boolean_nor_a_date('support') if product.data['activeSupportColumn']
      error_if.is_not_a_boolean_nor_a_date('eol') if product.data['eolColumn']
      error_if.is_not_a_boolean_nor_a_date('discontinued') if product.data['discontinuedColumn']
      error_if.is_not_a_boolean_nor_a_date('extendedSupport') if product.data['extendedSupportColumn']
      error_if.is_not_a_boolean_nor_a_date('lts') if release.has_key?('lts')
      error_if.is_not_a_string('latest') if product.data['releaseColumn']
      error_if.is_not_a_date('latestReleaseDate') if product.data['releaseColumn'] and release.has_key?('latestReleaseDate')
      error_if.is_not_an_url('link') if release.has_key?('link') and release['link']
    }

    Jekyll.logger.debug TOPIC, "Product '#{product.name}' successfully validated in #{(Time.now - start).round(3)} seconds."
  end

  def self.validate_urls(product)
    if ENV.fetch('MUST_CHECK_URLS', false)
      start = Time.now
      Jekyll.logger.info TOPIC, "Validating urls for '#{product.name}'..."

      error_if = Validator.new(product, product.data)
      error_if.is_url_invalid('releasePolicyLink') if product.data['releasePolicyLink']
      error_if.is_url_invalid('releaseImage') if product.data['releaseImage']
      error_if.is_url_invalid('iconUrl') if product.data['iconUrl']
      error_if.contains_invalid_urls(product.content)

      product.data['releases'].each { |release|
        error_if = Validator.new(product, release)
        error_if.is_url_invalid('link') if release['link']
      }

      Jekyll.logger.info TOPIC, "Product '#{product.name}' urls successfully validated in #{(Time.now - start).round(3)} seconds."
    end
  end

  private

  class Validator
    def initialize(product, data)
      @product = product
      @data = data
      @error_count = 0
    end

    def error_count
      @error_count
    end

    def is_not_an_array(property)
      value = @data[property]
      unless value.kind_of?(Array)
        declare_error(property, value, "expecting and Array, got #{value.class}")
      end
    end

    def is_not_in(property, valid_values)
      value = @data[property]
      unless valid_values.include?(value)
        declare_error(property, value, "expecting one of #{valid_values.join(', ')}")
      end
    end

    def does_not_match(property, regex)
      values = @data[property].kind_of?(Array) ? @data[property] : [@data[property]]
      values.each { |value|
        unless regex.match?(value)
          declare_error(property, value, "should match #{regex}")
        end
      }
    end

    def is_not_a_string(property)
      value = @data[property]
      unless value.kind_of?(String)
        declare_error(property, value, "expecting a value of type String, got #{value.class}")
      end
    end

    def is_not_an_url(property)
      does_not_match(property, /^https?:\/\/.+$/)
    end

    def is_not_a_date(property)
      value = @data[property]
      unless value.respond_to?(:strftime)
        declare_error(property, value, "expecting a value of type boolean or date, got #{value.class}")
      end
    end

    def too_far_in_future(property)
      value = @data[property]
      if value.respond_to?(:strftime) and value > Date.today + 30
        declare_error(property, value, "expecting a value in the next 30 days, got #{value}")
      end
    end

    def is_not_a_number(property)
      value = @data[property]
      unless value.kind_of?(Numeric)
        declare_error(property, value, "expecting a value of type numeric, got #{value.class}")
      end
    end

    def is_not_a_boolean_nor_a_date(property)
      value = @data[property]
      unless [true, false].include?(value) or value.respond_to?(:strftime)
        declare_error(property, value, "expecting a value of type boolean or date, got #{value.class}")
      end
    end

    def is_not_a_boolean_nor_a_string(property)
      value = @data[property]
      unless [true, false].include?(value) or value.kind_of?(String)
        declare_error(property, value, "expecting a value of type boolean or string, got #{value.class}")
      end
    end

    def is_url_invalid(property)
      # strip is necessary because changelogTemplate is sometime reformatted on two lines by latest.py
      url = @data[property].strip
      check_url(url)
    rescue => e
      declare_url_error(property, url, "got an error : '#{e}'")
    end

    # Retrieve all urls in the given markdown-formatted text and check them.
    def contains_invalid_urls(markdown)
      urls = markdown.scan(/]\((?<matching>http[^)"]+)/).flatten # matches [text](url) or [text](url "title")
      urls += markdown.scan(/<(?<matching>http[^>]+)/).flatten # matches <url>
      urls += markdown.scan(/: (?<matching>http[^"\n]+)/).flatten # matches [id]: url or [id]: url "title"
      urls.each do |url|
        begin
          check_url(url.strip) # strip url because matches on [text](url "title") end with a space
        rescue => e
          declare_url_error('content', url, "got an error : '#{e}'")
        end
      end
    end

    def check_url(url)
      ignored_reason = is_ignored(url)
      if ignored_reason
        Jekyll.logger.warn TOPIC, "Ignore URL #{url} : #{ignored_reason}."
        return
      end

      Jekyll.logger.debug TOPIC, "Checking URL #{url}."
      URI.open(url, 'User-Agent' => USER_AGENT, :open_timeout => URL_CHECK_OPEN_TIMEOUT, :read_timeout => URL_CHECK_TIMEOUT) do |response|
        if response.status[0].to_i >= 400
          raise "response code is #{response.status}"
        end
      end
    end

    def is_ignored(url)
      EndOfLifeHooks::IGNORED_URL_PREFIXES.each do |ignored_url, reason|
        return reason if url.start_with?(ignored_url.to_s)
      end

      return nil
    end

    def is_suppressed(url)
      EndOfLifeHooks::SUPPRESSED_URL_PREFIXES.each do |ignored_url, reason|
        return reason if url.start_with?(ignored_url.to_s)
      end

      return nil
    end

    def declare_url_error(property, url, details)
      reason = is_suppressed(url)
      if reason
        Jekyll.logger.warn TOPIC, "Invalid #{property} '#{url}' for #{location}, #{details} (suppressed: #{reason})."
      else
        declare_error(property, url, details)
      end

    end

    def declare_error(property, value, details)
      Jekyll.logger.error TOPIC, "Invalid #{property} '#{value}' for #{location}, #{details}."
      EndOfLifeHooks::increase_error_count()
    end

    def location
      @data.has_key?('releaseCycle') ? "#{@product.name}##{@data['releaseCycle']}" : @product.name
    end
  end
end

# Must be run before enrichment, hence the high priority.
Jekyll::Hooks.register :pages, :post_init, priority: Jekyll::Hooks::PRIORITY_MAP[:high] do |page, payload|
  if page.data['layout'] == 'product'
    EndOfLifeHooks::validate(page)
  end
end

# Must be run after enrichment, hence the low priority.
Jekyll::Hooks.register :pages, :post_init, priority: Jekyll::Hooks::PRIORITY_MAP[:low] do |page, payload|
  if page.data['layout'] == 'product'
    EndOfLifeHooks::validate_urls(page)
  end
end

# Must be run at the end of all validation
Jekyll::Hooks.register :site, :post_render, priority: Jekyll::Hooks::PRIORITY_MAP[:low] do |site, payload|
  if EndOfLifeHooks::error_count > 0
    raise "Site build canceled : #{EndOfLifeHooks::error_count} errors detected"
  end
end
