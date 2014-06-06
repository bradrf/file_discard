#!/usr/bin/env ruby

begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  # not required, but nice for reports on what code the tests have touched
end

require 'tmpdir'
require 'minitest/spec'
require 'minitest/autorun'

load File.expand_path(File.join(File.dirname(__FILE__),'..','lib','file_discard.rb'))

describe FileDiscard do

  describe :Discarder do
    before do
      @base = Pathname.new(Dir.mktmpdir(File.basename(__FILE__,'.rb') + '_'))
      @home = @base.join('home')
      @home.mkdir
      @home_trash = '.Trash'

      @discarder = FileDiscard::OsxDiscarder.new(@home)
      FileDiscard.discarder = @discarder
    end

    after do
      @base.rmtree if @base && @base.exist?
    end

    it 'should not allow removal of special directories' do
      ['.','..'].each do |dir|
        ->{ FileDiscard.discard(dir) }.must_raise Errno::EINVAL
      end
    end

    describe 'when mixed in' do
      before do
        FileDiscard.mix_it_in!
      end

      it 'should extend classes' do
        [File, Pathname].each do |klass|
          klass.must_respond_to :discard
        end
      end

      it 'should fail without trash' do
        f = File.new(@base.join('file.txt').to_s, 'w')
        ->{ f.discard }.must_raise Errno::ENOENT
      end

      describe 'with trash in the home' do
        before do
          @trash = @home.join(@home_trash)
          @trash.mkdir
        end

        def sorted_trash
          @trash.children(false).collect(&:to_s).sort
        end

        it 'should discard a file' do
          f = File.new(@base.join('file.txt').to_s, 'w')
          f.discard
          sorted_trash.must_equal ['file.txt']
        end

        it 'should discard a pathname' do
          f = @base.join('file.txt')
          f.open('w') {|io| io.puts 'nothing'}
          f.discard
          sorted_trash.must_equal ['file.txt']
        end

        describe 'with control over time' do
          before do
            # replace Time's strftime which FileDiscard relies on for uniquify
            class Time
              alias :orig_strftime :strftime
              @@strftime_count = 0
              def strftime(fmt)
                @@strftime_count += 1
                "9.8.#{@@strftime_count}"
              end
            end
          end

          after do
            if Time.now.respond_to? :orig_strftime
              class Time
                alias :strftime :orig_strftime
              end
            end
          end

          it 'should not overwite other trashed files' do
            f = @trash.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}

            f = @base.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}
            FileDiscard.discard(f.to_s)
            sorted_trash.must_equal ['file 9.8.1.txt','file.txt']
          end

          it 'should use increasing precision for collisions' do
            3.times do |i|
              f = @trash.join(%{file#{i == 0 ? '' : " 9.8.#{i}"}.txt})
              f.open('w') {|io| io.puts 'nothing'}
            end

            f = @base.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}
            File.discard(f.to_s)
            sorted_trash
              .must_equal ['file 9.8.1.txt', 'file 9.8.2.txt', 'file 9.8.3.txt', 'file.txt']
          end
        end

        describe 'with control over mountpoints' do
          class MyDiscarder < FileDiscard::Discarder
            private
            def mountpoint_of(pn)
              pn
            end
          end

          before do
            @trash = @base.join('mytrash-%s' % Process.uid)
            @trash.mkdir
            @discarder = MyDiscarder.new(@home, 'mytrash', 'mytrash-%s')
            FileDiscard.discarder = @discarder
          end

          it 'should not use the home trash' do
            f = @base.join('file.txt')
            f.open('w') {|io| io.puts 'nothing'}
            f.discard
            sorted_trash.must_equal ['file.txt']
          end
        end
      end
    end
  end
end
