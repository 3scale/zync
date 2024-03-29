# frozen_string_literal: true

namespace :ci do
  namespace :license_finder do
    desc 'Run compliance task and generates the license report if complies'
    task run: :environment do
      if Rake::Task['ci:license_finder:compliance'].invoke
        Rake::Task['ci:license_finder:report'].invoke
      end
    end
    desc 'Check license compliance of dependencies'
    task compliance: :environment do
      STDOUT.puts 'Checking license compliance'
      unless system("bundle exec license_finder")
        STDERR.puts "*** License compliance test failed  ***"
        exit 1
      end
    end
    desc 'Generates a report with the dependencies and their licenses'
    task report: :environment do
      STDOUT.puts 'Generating report...'
      exec(%[bundle exec license_finder report --format=xml --save="#{Rails.root.join('doc/licenses/licenses.xml')}"])
    end
  end
end
