task :default => :push


desc "ps"
task :deploy do
     sh 'git ps origin master'
     sh 'git ps blog_origin master'
end

desc "commit"
task :ci, :msg do |t, args|
     mm = args[:msg]
     sh "echo #{mm}"
end

desc "deploy"
task :deploy, :msg do |t, args|
      mm = args[:msg]
      sh "git add ."
      sh "git ci -am #{mm}"
	Rake::Task["tt"].execute(t,mm)
      Rake::Task["ps"].execute
 end

desc "tt"
task :tt , :msg do |t,args|
	pp = args[:msg]	
	sh "echo #{pp}"
end
