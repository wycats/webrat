require "hpricot"
require "webrat/core/form"
require "webrat/core/assertions"

module Webrat
  class Scope
    include Logging
    include Flunk
    include Assertions
    
    def initialize(session, html, selector = nil)
      @session  = session
      @html     = html
      @selector = selector
    end
    
    # Verifies an input field or textarea exists on the current page, and stores a value for
    # it which will be sent when the form is submitted.
    #
    # Examples:
    #   fills_in "Email", :with => "user@example.com"
    #   fills_in "user[email]", :with => "user@example.com"
    #
    # The field value is required, and must be specified in <tt>options[:with]</tt>.
    # <tt>field</tt> can be either the value of a name attribute (i.e. <tt>user[email]</tt>)
    # or the text inside a <tt><label></tt> element that points at the <tt><input></tt> field.
    def fills_in(id_or_name_or_label, options = {})
      field = find_field(id_or_name_or_label, TextField, TextareaField, PasswordField)
      field.raise_error_if_disabled
      field.set(options[:with])
    end

    alias_method :fill_in, :fills_in
    
    # Verifies that an input checkbox exists on the current page and marks it
    # as checked, so that the value will be submitted with the form.
    #
    # Example:
    #   checks 'Remember Me'
    def checks(id_or_name_or_label)
      find_field(id_or_name_or_label, CheckboxField).check
    end

    alias_method :check, :checks
    
    # Verifies that an input checkbox exists on the current page and marks it
    # as unchecked, so that the value will not be submitted with the form.
    #
    # Example:
    #   unchecks 'Remember Me'
    def unchecks(id_or_name_or_label)
      find_field(id_or_name_or_label, CheckboxField).uncheck
    end

    alias_method :uncheck, :unchecks
    
    # Verifies that an input radio button exists on the current page and marks it
    # as checked, so that the value will be submitted with the form.
    #
    # Example:
    #   chooses 'First Option'
    def chooses(label)
      find_field(label, RadioField).choose
    end

    alias_method :choose, :chooses
    
    # Verifies that a an option element exists on the current page with the specified
    # text. You can optionally restrict the search to a specific select list by
    # assigning <tt>options[:from]</tt> the value of the select list's name or
    # a label. Stores the option's value to be sent when the form is submitted.
    #
    # Examples:
    #   selects "January"
    #   selects "February", :from => "event_month"
    #   selects "February", :from => "Event Month"
    def selects(option_text, options = {})
      find_select_option(option_text, options[:from]).choose
    end

    alias_method :select, :selects
    
    # Verifies that an input file field exists on the current page and sets
    # its value to the given +file+, so that the file will be uploaded
    # along with the form. An optional <tt>content_type</tt> may be given.
    #
    # Example:
    #   attaches_file "Resume", "/path/to/the/resume.txt"
    #   attaches_file "Photo", "/path/to/the/image.png", "image/png"
    def attaches_file(id_or_name_or_label, path, content_type = nil)
      find_field(id_or_name_or_label, FileField).set(path, content_type)
    end

    alias_method :attach_file, :attaches_file
    
    def clicks_area(area_name)
      find_area(area_name).click
    end
    
    alias_method :click_area, :clicks_area
    
    # Issues a request for the URL pointed to by a link on the current page,
    # follows any redirects, and verifies the final page load was successful.
    # 
    # clicks_link has very basic support for detecting Rails-generated 
    # JavaScript onclick handlers for PUT, POST and DELETE links, as well as
    # CSRF authenticity tokens if they are present.
    #
    # Javascript imitation can be disabled by passing the option :javascript => false
    #
    # Passing a :method in the options hash overrides the HTTP method used
    # for making the link request
    # 
    # Example:
    #   clicks_link "Sign up"
    #
    #   clicks_link "Sign up", :javascript => false
    # 
    #   clicks_link "Sign up", :method => :put
    def clicks_link(link_text, options = {})
      find_link(link_text).click(options)
    end

    alias_method :click_link, :clicks_link

    def clicks_get_link(link_text) # :nodoc:
      clicks_link link_text, :method => :get
    end

    alias_method :click_get_link, :clicks_get_link

    def clicks_delete_link(link_text) # :nodoc:
      clicks_link link_text, :method => :delete
    end

    alias_method :click_delete_link, :clicks_delete_link

    def clicks_post_link(link_text) # :nodoc:
      clicks_link link_text, :method => :post
    end

    alias_method :click_post_link, :clicks_post_link

    def clicks_put_link(link_text) # :nodoc:
      clicks_link link_text, :method => :put
    end

    alias_method :click_put_link, :clicks_put_link
    
    # Verifies that a submit button exists for the form, then submits the form, follows
    # any redirects, and verifies the final page was successful.
    #
    # Example:
    #   clicks_button "Login"
    #   clicks_button
    #
    # The URL and HTTP method for the form submission are automatically read from the
    # <tt>action</tt> and <tt>method</tt> attributes of the <tt><form></tt> element.
    def clicks_button(value = nil)
      find_button(value).click
    end

    alias_method :click_button, :clicks_button
    
    def dom # :nodoc:
      @dom ||= Hpricot(scoped_html)
    end
    
    def field_labeled(label)
      find_field(label, TextField, TextareaField, CheckboxField, RadioField, HiddenField)
    end
    
  protected
  
    def scoped_html
      @scoped_html ||= begin
        if @selector
          (Hpricot(@html) / @selector).first.to_html
        else
          @html
        end
      end
    end
  
    def find_select_option(option_text, id_or_name_or_label)
      if id_or_name_or_label
        field = find_field(id_or_name_or_label, SelectField)
        return field.find_option(option_text)
      else
        forms.each do |form|
          result = form.find_select_option(option_text)
          return result if result
        end
      end
        
      flunk("Could not find option #{option_text.inspect}")
    end
    
    def find_button(value)
      forms.each do |form|
        button = form.find_button(value)
        return button if button
      end
      flunk("Could not find button #{value.inspect}")
    end
    
    def find_area(area_name)
      areas.select{|area| area.matches_text?(area_name)}.first || flunk("Could not find area with name #{area_name}")
    end
    
    def areas
      (dom / "area").map do |element| 
        Area.new(@session, element)
      end
    end
    
    def find_link(text, selector = nil)
      matching_links = links_within(selector).select do |possible_link|
        possible_link.matches_text?(text)
      end
      
      if matching_links.any?
        matching_links.min { |a, b| a.text.length <=> b.text.length }
      else
        flunk("Could not find link with text #{text.inspect}")
      end
    end
    
    def find_field(id_or_name_or_label, *field_types)
      forms.each do |form|
        result = form.find_field(id_or_name_or_label, *field_types)
        return result if result
      end
      
      flunk("Could not find #{field_types.inspect}: #{id_or_name_or_label.inspect}")
    end
    
    def links_within(selector)
      (dom / selector / "a[@href]").map do |link_element|
        Link.new(@session, link_element)
      end
    end
    
    def forms
      return @forms if @forms
      
      @forms = (dom / "form").map do |form_element|
        Form.new(@session, form_element)
      end
    end
    
  end
end